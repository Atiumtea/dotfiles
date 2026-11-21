{
    config,
    lib,
    pkgs,
    ...
}: {
    options = {
        userSettings = {
            security.enable = lib.mkEnableOption "security features";
        };
    };

    config = lib.mkIf config.userSettings.security.enable {
        home.packages = with pkgs; [
            age
            sops
        ];

        sops = {
            defaultSopsFile = ../../hosts/x1extreme/secrets.yaml;
            age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

            secrets."github-token" = {
                key = "gh/token";
                mode = "0400";
            };
        };

        programs = {
            gpg.enable = true;
            ssh = {
                enable = true;
                enableDefaultConfig = false;
                settings."*".AddKeysToAgent = "yes";
            };
        };

        services = {
            ssh-agent.enable = true;
            gpg-agent = {
                enable = true;
                enableSshSupport = false;
                pinentry = {
                    package = pkgs.pinentry-qt;
                    program = "pinentry-qt";
                };
            };
        };

        programs.zsh.initContent = lib.mkBefore ''
            export GPG_TTY=$(tty)

            gh() {
                local token_file=${lib.escapeShellArg config.sops.secrets."github-token".path}

                if [[ ! -r "$token_file" ]]; then
                    printf '%s\\n' "gh: SOPS token is unavailable; check sops-nix.service." >&2
                    return 1
                fi

                local token
                token="$(< "$token_file")"

                if [[ -z "$token" ]]; then
                    printf '%s\\n' "gh: decrypted token is empty." >&2
                    return 1
                fi

                GH_TOKEN="$token" command ${pkgs.gh}/bin/gh "$@"
            }
        '';
    };
}
