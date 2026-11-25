#!/usr/bin/env python3
"""Maintain a persistent inventory and metadata archive for NixOS generations."""
from __future__ import annotations

import argparse
import datetime as dt
import fcntl
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

DEFAULT_PROFILE = Path("/nix/var/nix/profiles/system")
STORE_HASH_RE = re.compile(r"^/nix/store/([0-9a-z]{32})-")
GENERATION_RE = re.compile(r"^system-([0-9]+)-link$")
SCHEMA_VERSION = 1


def state_directory() -> Path:
    root = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    parent = root / "nixos-control-center"
    directory = parent / "generations"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(parent, 0o700)
    os.chmod(directory, 0o700)
    return directory


def record_key(generation: str, store_hash: str) -> str:
    return f"gen-{generation}-{store_hash}.json"


def store_hash_for(path: str) -> str:
    match = STORE_HASH_RE.match(path)
    return match.group(1) if match else "unknown"


def live_generations(profile: Path) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    pattern = f"{glob.escape(str(profile))}-*-link"

    for link_name in glob.glob(pattern):
        link = Path(link_name)
        match = GENERATION_RE.match(link.name)
        if not match or not link.is_symlink():
            continue

        generation = match.group(1)
        store_path = os.path.realpath(link)
        try:
            created_at = int(os.lstat(link).st_mtime)
        except OSError:
            created_at = None

        result.append(
            {
                "generation": generation,
                "storeHash": store_hash_for(store_path),
                "storePath": store_path,
                "createdAtEpoch": created_at,
            }
        )

    result.sort(key=lambda item: (int(item["generation"]), item["storeHash"]))
    return result


def load_record(path: Path) -> dict[str, Any] | None:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return value if isinstance(value, dict) else None


def save_record(directory: Path, record: dict[str, Any]) -> Path:
    path = directory / record_key(record["generation"], record["storeHash"])
    fd, temporary_name = tempfile.mkstemp(prefix=".generation-", suffix=".tmp", dir=directory)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(record, stream, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_name, path)
        os.chmod(path, 0o600)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except OSError:
            pass
        raise
    return path


def locked(directory: Path):
    lock_file = (directory / ".lock").open("a+")
    os.chmod(lock_file.name, 0o600)
    fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
    return lock_file


def sync_inventory(profile: Path) -> int:
    directory = state_directory()
    lock_file = locked(directory)
    created = 0
    try:
        for live in live_generations(profile):
            path = directory / record_key(live["generation"], live["storeHash"])
            existing = load_record(path) if path.exists() else None
            if existing is None:
                record = {
                    "schema": SCHEMA_VERSION,
                    **live,
                    "captureStatus": "inventory",
                }
                save_record(directory, record)
                created += 1
            else:
                changed = False
                for key in ("storePath", "createdAtEpoch"):
                    if existing.get(key) != live.get(key):
                        existing[key] = live.get(key)
                        changed = True
                existing.setdefault("schema", SCHEMA_VERSION)
                if changed:
                    save_record(directory, existing)
    finally:
        lock_file.close()
    return created


def read_lock_nixpkgs_revision(dotfiles: Path) -> str | None:
    try:
        lock = json.loads((dotfiles / "flake.lock").read_text(encoding="utf-8"))
        node = lock.get("nodes", {}).get("root", {}).get("inputs", {}).get("nixpkgs")
        if isinstance(node, list):
            node = node[0] if node else None
        if not isinstance(node, str):
            return None
        revision = lock.get("nodes", {}).get(node, {}).get("locked", {}).get("rev")
        return revision if isinstance(revision, str) else None
    except (OSError, json.JSONDecodeError, IndexError):
        return None


def run_json_command(command: list[str], error_stream) -> Any:
    completed = subprocess.run(command, check=False, stdout=subprocess.PIPE, stderr=error_stream, text=True)
    if completed.returncode != 0:
        raise RuntimeError(f"command exited with status {completed.returncode}: {' '.join(command)}")
    try:
        return json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"command returned invalid JSON: {' '.join(command)}") from error


def path_info_entries(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, dict):
        values = payload.values()
    elif isinstance(payload, list):
        values = payload
    else:
        raise RuntimeError("unexpected nix path-info JSON shape")
    return [entry for entry in values if isinstance(entry, dict)]


def package_evaluation(dotfiles: Path, host: str, user: str, error_stream) -> dict[str, Any]:
    expression = (
        "config: { "
        "nixosPackageNames = builtins.map (package: package.name or (builtins.baseNameOf (toString package))) config.environment.systemPackages; "
        f"homePackageNames = builtins.map (package: package.name or (builtins.baseNameOf (toString package))) config.home-manager.users.{user}.home.packages; "
        "nixosVersion = config.system.nixos.version; "
        "kernelVersion = config.boot.kernelPackages.kernel.version; "
        "}"
    )
    return run_json_command(
        [
            "nix", "eval", "--json", "--show-trace",
            f"{dotfiles}#nixosConfigurations.{host}.config",
            "--apply", expression,
        ],
        error_stream,
    )


def capture_generation(
    profile: Path,
    generation: str,
    action: str,
    host: str,
    user: str,
    dotfiles: Path,
    build_log: Path | None,
) -> dict[str, Any]:
    directory = state_directory()
    sync_inventory(profile)
    live = next((item for item in live_generations(profile) if item["generation"] == str(generation)), None)
    if live is None:
        raise RuntimeError(f"generation {generation} is not present in {profile}-*-link")

    path = directory / record_key(live["generation"], live["storeHash"])
    record = load_record(path) if path.exists() else None
    if record is None:
        record = {"schema": SCHEMA_VERSION, **live, "captureStatus": "inventory"}

    if build_log is not None:
        build_log.parent.mkdir(parents=True, exist_ok=True)
        error_stream = build_log.open("a", encoding="utf-8")
    else:
        error_stream = sys.stderr

    path_info_ok = False
    eval_ok = False
    try:
        try:
            path_info = run_json_command(
                ["nix", "path-info", "--recursive", "--json", "--no-pretty", live["storePath"]],
                error_stream,
            )
            entries = path_info_entries(path_info)
            nar_sizes = [int(entry["narSize"]) for entry in entries if isinstance(entry.get("narSize"), (int, float))]
            if entries and len(nar_sizes) == len(entries):
                record["closurePaths"] = len(entries)
                record["closureNarSizeBytes"] = sum(nar_sizes)
                path_info_ok = True
            else:
                print("generation metadata: nix path-info did not return narSize for every closure path", file=error_stream)
        except (RuntimeError, OSError, ValueError) as error:
            print(f"generation metadata: closure query failed: {error}", file=error_stream)

        try:
            evaluated = package_evaluation(dotfiles, host, user, error_stream)
            for source_key, target_key in (
                ("nixosPackageNames", "nixosPackageNames"),
                ("homePackageNames", "homePackageNames"),
            ):
                names = evaluated.get(source_key)
                if isinstance(names, list):
                    normalized = sorted({str(name) for name in names})
                    record[target_key] = normalized
                    count_key = "nixosPackages" if source_key == "nixosPackageNames" else "homePackages"
                    record[count_key] = len(normalized)
            for key in ("nixosVersion", "kernelVersion"):
                if key in evaluated:
                    record[key] = evaluated[key]
            eval_ok = all(key in record for key in ("nixosPackages", "homePackages"))
        except (RuntimeError, OSError, ValueError) as error:
            print(f"generation metadata: configuration evaluation failed: {error}", file=error_stream)
    finally:
        if build_log is not None:
            error_stream.close()

    git_commit = subprocess.run(
        ["git", "-C", str(dotfiles), "rev-parse", "HEAD"],
        check=False, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
    )
    git_status = subprocess.run(
        ["git", "-C", str(dotfiles), "status", "--porcelain"],
        check=False, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
    )

    record.update(
        {
            **live,
            "action": action,
            "host": host,
            "capturedAt": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
            "dotfilesCommit": git_commit.stdout.strip() if git_commit.returncode == 0 else None,
            "dotfilesDirty": bool(git_status.stdout.strip()) if git_status.returncode == 0 else None,
            "nixpkgsRev": read_lock_nixpkgs_revision(dotfiles),
            "captureStatus": "captured" if path_info_ok and eval_ok else "partial",
        }
    )

    lock_file = locked(directory)
    try:
        current = load_record(path) if path.exists() else {}
        if current:
            current.update(record)
            record = current
        save_record(directory, record)
    finally:
        lock_file.close()
    return record


def format_bytes(value: int) -> str:
    amount = float(value)
    units = ("B", "KiB", "MiB", "GiB", "TiB")
    index = 0
    while abs(amount) >= 1024 and index < len(units) - 1:
        amount /= 1024
        index += 1
    if index == 0:
        return f"{int(amount)} {units[index]}"
    return f"{amount:.2f} {units[index]}"


def format_signed_bytes(value: int) -> str:
    sign = "+" if value > 0 else "" if value < 0 else "±"
    return f"{sign}{format_bytes(value)}"


def list_records(profile: Path) -> list[dict[str, Any]]:
    sync_inventory(profile)
    directory = state_directory()
    lock_file = locked(directory)
    try:
        records = [
            record for path in directory.glob("gen-*.json")
            if (record := load_record(path)) is not None
        ]
    finally:
        lock_file.close()

    live = {
        (item["generation"], item["storeHash"]): item
        for item in live_generations(profile)
    }
    selected_path = os.path.realpath(profile)
    running_path = os.path.realpath("/run/current-system")

    ascending = sorted(records, key=lambda item: (int(item.get("generation", 0)), item.get("storeHash", "")))
    previous: dict[str, Any] | None = None
    for record in ascending:
        generation = str(record.get("generation", "-"))
        key = (generation, str(record.get("storeHash", "unknown")))
        present_item = live.get(key)
        record["present"] = present_item is not None
        record["displayDate"] = (
            dt.datetime.fromtimestamp(record["createdAtEpoch"]).strftime("%Y-%m-%d")
            if isinstance(record.get("createdAtEpoch"), (int, float)) else "-"
        )

        store_path = record.get("storePath", "")
        if present_item is None:
            record["systemState"] = "ARCHIVED"
        elif store_path == running_path:
            record["systemState"] = "RUNNING"
        elif store_path == selected_path:
            record["systemState"] = "NEXT BOOT"
        else:
            record["systemState"] = "AVAILABLE"

        record["commitShort"] = (record.get("dotfilesCommit") or "-")[:8]
        record["nixpkgsShort"] = (record.get("nixpkgsRev") or "-")[:12]
        dirty_state = record.get("dotfilesDirty")
        record["sourceState"] = "DIRTY" if dirty_state is True else "CLEAN" if dirty_state is False else "-"
        record["closureSizeLabel"] = (
            format_bytes(int(record["closureNarSizeBytes"]))
            if isinstance(record.get("closureNarSizeBytes"), (int, float)) else "-"
        )
        record["closurePathsLabel"] = str(record.get("closurePaths", "-"))
        record["nixosPackagesLabel"] = str(record.get("nixosPackages", "-"))
        record["homePackagesLabel"] = str(record.get("homePackages", "-"))

        delta_parts: list[str] = []
        previous_generation = str(previous.get("generation")) if previous else None
        if previous is not None:
            if isinstance(record.get("closureNarSizeBytes"), (int, float)) and isinstance(previous.get("closureNarSizeBytes"), (int, float)):
                delta_parts.append(f"NAR {format_signed_bytes(int(record['closureNarSizeBytes']) - int(previous['closureNarSizeBytes']))}")
            if isinstance(record.get("closurePaths"), int) and isinstance(previous.get("closurePaths"), int):
                delta_parts.append(f"paths {record['closurePaths'] - previous['closurePaths']:+d}")
            if isinstance(record.get("nixosPackages"), int) and isinstance(previous.get("nixosPackages"), int):
                delta_parts.append(f"NixOS {record['nixosPackages'] - previous['nixosPackages']:+d}")
            if isinstance(record.get("homePackages"), int) and isinstance(previous.get("homePackages"), int):
                delta_parts.append(f"HM {record['homePackages'] - previous['homePackages']:+d}")
            package_diffs = []
            comparable_package_sets = 0
            for prefix, key in (("NixOS", "nixosPackageNames"), ("HM", "homePackageNames")):
                current_values = record.get(key)
                previous_values = previous.get(key)
                if not isinstance(current_values, list) or not isinstance(previous_values, list):
                    continue
                comparable_package_sets += 1
                current_names = set(current_values)
                previous_names = set(previous_values)
                added = sorted(current_names - previous_names)
                removed = sorted(previous_names - current_names)
                if added or removed:
                    added_label = ", ".join(added[:3]) + (f" +{len(added) - 3} more" if len(added) > 3 else "")
                    removed_label = ", ".join(removed[:3]) + (f" +{len(removed) - 3} more" if len(removed) > 3 else "")
                    package_diffs.append(f"{prefix} +[{added_label or '-'}] -[{removed_label or '-'}]")
            if comparable_package_sets == 0:
                record["packageDiffLabel"] = "Package diff unavailable"
            else:
                record["packageDiffLabel"] = " · ".join(package_diffs) if package_diffs else "No package-name changes"
        else:
            record["packageDiffLabel"] = "Package diff unavailable"
        record["deltaLabel"] = (
            f"Δ vs #{previous_generation}: " + " · ".join(delta_parts)
            if previous is not None and delta_parts else "Δ -"
        )
        previous = record

    records.sort(key=lambda item: (int(item.get("generation", 0)), item.get("storeHash", "")), reverse=True)
    return records


def current_generation_number(profile: Path) -> str:
    try:
        target = os.readlink(profile)
    except OSError as error:
        raise RuntimeError(f"cannot read system profile {profile}: {error}") from error
    match = GENERATION_RE.match(Path(target).name)
    if match:
        return match.group(1)
    selected_path = os.path.realpath(profile)
    current = next((item for item in live_generations(profile) if item["storePath"] == selected_path), None)
    if current is not None:
        return current["generation"]
    raise RuntimeError(f"could not determine the selected generation from {profile}")


def command_capture_current(args: argparse.Namespace) -> int:
    args.generation = current_generation_number(Path(args.profile))
    return command_capture(args)


def command_sync(args: argparse.Namespace) -> int:
    created = sync_inventory(Path(args.profile))
    print(f"Indexed system generations; {created} new history record(s) created.")
    return 0


def command_list(args: argparse.Namespace) -> int:
    json.dump(list_records(Path(args.profile)), sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


def command_capture(args: argparse.Namespace) -> int:
    record = capture_generation(
        profile=Path(args.profile),
        generation=args.generation,
        action=args.action,
        host=args.host,
        user=args.user,
        dotfiles=Path(args.dotfiles).resolve(),
        build_log=Path(args.build_log) if args.build_log else None,
    )
    print(
        f"Generation {record['generation']}: {record.get('closureSizeLabel', 'metadata pending')} NAR closure, "
        f"{record.get('closurePaths', '-')} paths, "
        f"{record.get('nixosPackages', '-')} NixOS / {record.get('homePackages', '-')} HM packages "
        f"({record['captureStatus']})."
    )
    return 0 if record["captureStatus"] == "captured" else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    for command in ("sync", "list"):
        sub = subparsers.add_parser(command)
        sub.add_argument("--profile", default=str(DEFAULT_PROFILE))

    capture = subparsers.add_parser("capture")
    capture_current = subparsers.add_parser("capture-current")
    for sub in (capture, capture_current):
        sub.add_argument("--profile", default=str(DEFAULT_PROFILE))
        sub.add_argument("--action", choices=("switch", "boot", "baseline"), default="switch")
        sub.add_argument("--host", required=True)
        sub.add_argument("--user", default=os.environ.get("USER") or os.environ.get("LOGNAME") or "")
        sub.add_argument("--dotfiles", default=str(Path.home() / "dotfiles"))
        sub.add_argument("--build-log")
    capture.add_argument("--generation", required=True)
    capture_current.set_defaults(action="baseline")

    args = parser.parse_args()
    if args.command == "sync":
        return command_sync(args)
    if args.command == "list":
        return command_list(args)
    if args.command in ("capture", "capture-current"):
        if not re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_]*", args.user):
            parser.error("--user must be a valid Nix attribute name")
        if args.command == "capture-current":
            return command_capture_current(args)
        return command_capture(args)
    return 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError) as error:
        print(f"nixos-control-generations: {error}", file=sys.stderr)
        raise SystemExit(1)
