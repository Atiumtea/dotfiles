{lib, ...}: let
    collectDirs = path: (builtins.attrNames (lib.filterAttrs (name: type: type == "directory") (builtins.readDir path)));
in {
    inherit collectDirs;
}
