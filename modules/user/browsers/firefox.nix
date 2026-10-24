{
    config,
    osConfig,
    lib,
    pkgs,
    ...
}: let
    package = pkgs.firefox;
in {
    options = {
        userSettings = {
            browsers.firefox = {
                enable = lib.mkEnableOption "Firefox";
                path = lib.mkOption {
                    default = "${package}/share/applications/firefox.desktop";
                    internal = true;
                    visible = false;
                    readOnly = true;
                };
            };
        };
    };

    config = lib.mkIf config.userSettings.browsers.firefox.enable {
        programs.firefox = {
            inherit package;

            enable = true;
            profiles.default = {
                isDefault = true;
                preConfig = builtins.readFile "${pkgs.arkenfox-userjs}/user.js";
                settings = {
                    # arkenfox overrides
                    "browser.startup.page" = 3;

                    # "captivedetect.canonicalURL" = "http://detectportal.firefox.com/canonical.html";
                    # "network.captive-portal-service.enabled" = true;

                    "browser.send_pings" = false;

                    "network.trr.mode" =
                        if (osConfig.services ? blocky && osConfig.services.blocky.enable)
                        then 5
                        else 3;
                    # Mozilla's DoH resolver has stronger privacy policy
                    "network.trr.uri" = "https://mozilla.cloudflare-dns.com/dns-query";
                    "network.trr.custom_uri" = "https://mozilla.cloudflare-dns.com/dns-query";

                    "browser.search.suggest.enabled" = true;
                    "browser.urlbar.suggest.searches" = true;
                    "browser.formfill.enable" = true;
                    "browser.cache.disk.enable" = true;
                    "browser.sessionstore.privacy_level" = 2;
                    "network.IDN_show_punycode" = false;
                    "browser.download.useDownloadDir" = true;
                    "browser.download.always_ask_before_handling_new_types" = false;

                    "privacy.sanitize.sanitizeOnShutdown" = false;
                    "privacy.clearOnShutdown_v2.formdata" = false;
                    "privacy.clearOnShutdown_v2.cookiesAndStorage" = false;

                    # Relax FPP: keep colorscheme detection, keep local timezone
                    "privacy.fingerprintingProtection.overrides" = "+AllTargets,-CSSPrefersColorScheme,-JSDateTimeUTC";

                    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
                };
                search = {
                    default = "ddg";
                    privateDefault = "ddg";
                    engines = {
                        bing.metaData.hidden = true;
                        google.metaData.hidden = true;
                        ecosia.metaData.hidden = true;
                        perplexity.metaData.hidden = true;
                        wikipedia.metaData.hidden = true;
                    };
                    force = true;
                };
                extensions = {
                    packages = with pkgs.firefoxAddons; [
                        ublock-origin
                        privacy-badger17
                        consent-o-matic
                        skip-redirect
                    ];
                };
            };
        };

        stylix.targets.firefox.profileNames = ["default"];
    };
}
