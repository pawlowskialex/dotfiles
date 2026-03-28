{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.fish-ai;
  hasSecrets = cfg.secrets != { };

  # Merge op:// references into contexts as api_key values wrapped in {{ }}
  contextsWithSecrets = lib.mapAttrs (
    name: ctx:
    ctx
    // lib.optionalAttrs (cfg.secrets ? ${name}) {
      api_key = "{{ ${cfg.secrets.${name}} }}";
    }
  ) cfg.contexts;

  ini = lib.generators.toINI { } (
    {
      fish-ai = {
        inherit (cfg) configuration;
      };
    }
    // contextsWithSecrets
  );

  templateFile = pkgs.writeText "fish-ai.ini.tpl" ini;
  configPath = "\${XDG_CONFIG_HOME:-$HOME/.config}/fish-ai.ini";
in
{
  options.programs.fish-ai = {
    enable = lib.mkEnableOption "fish-ai, an AI plugin for the fish shell";

    package = lib.mkOption {
      type = lib.types.path;
      description = "Path to the fish-ai source (e.g. a flake input).";
    };

    configuration = lib.mkOption {
      type = lib.types.str;
      default = "anthropic";
      description = "The default context name to use.";
    };

    contexts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = {
        anthropic = {
          provider = "anthropic";
          model = "claude-sonnet-4-6";
        };
      };
      description = "Provider contexts. Each key becomes an INI section.";
    };

    secrets = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Map of context names to 1Password secret references (op:// URIs) for API keys.";
      example = {
        anthropic = "op://Personal/Anthropic API Key/credential";
      };
    };

    pythonVersion = lib.mkOption {
      type = lib.types.str;
      default = "3.13";
      description = "Python version for the fish-ai virtualenv.";
    };
  };

  config = lib.mkIf cfg.enable {
    # fish plugin files
    xdg.configFile =
      let
        functions = [
          "_fish_ai_autocomplete"
          "_fish_ai_autocomplete_or_fix"
          "_fish_ai_codify"
          "_fish_ai_codify_or_explain"
          "_fish_ai_explain"
          "_fish_ai_fix"
          "fish_ai_bug_report"
          "fish_ai_put_api_key"
          "fish_ai_switch_context"
        ];
      in
      {
        "fish/conf.d/fish_ai.fish".source = "${cfg.package}/conf.d/fish_ai.fish";
      }
      # Only manage the INI directly if there are no secrets to inject
      // lib.optionalAttrs (!hasSecrets) {
        "fish-ai.ini".text = ini;
      }
      // lib.listToAttrs (
        map (f: {
          name = "fish/functions/${f}.fish";
          value = {
            source = "${cfg.package}/functions/${f}.fish";
          };
        }) functions
      );

    home.activation.fish-ai = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      # Set up python venv
      ''
        FISH_AI_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/fish-ai"
        _fish_ai_install() {
          TMP_SRC=$(${pkgs.coreutils}/bin/mktemp -d)
          ${pkgs.coreutils}/bin/cp -r "${cfg.package}/." "$TMP_SRC/"
          chmod -R u+w "$TMP_SRC"
          "$FISH_AI_DIR/bin/pip" -qq install "$TMP_SRC"
          rm -rf "$TMP_SRC"
        }
        if [ ! -f "$FISH_AI_DIR/bin/lookup_setting" ]; then
          ${pkgs.uv}/bin/uv venv --quiet --seed --python ${cfg.pythonVersion} "$FISH_AI_DIR"
          _fish_ai_install
        elif [ "${cfg.package}" != "$(cat "$FISH_AI_DIR/.fish-ai-src" 2>/dev/null)" ]; then
          _fish_ai_install
        fi
        echo -n "${cfg.package}" > "$FISH_AI_DIR/.fish-ai-src"
      ''
      # Inject secrets from 1Password if configured
      + lib.optionalString hasSecrets ''
        CONFIG="${configPath}"
        TEMPLATE="${templateFile}"
        TEMPLATE_HASH=$(${pkgs.coreutils}/bin/sha256sum "$TEMPLATE" | cut -d' ' -f1)
        if [ ! -f "$CONFIG" ] || [ "$(cat "$CONFIG.hash" 2>/dev/null)" != "$TEMPLATE_HASH" ]; then
          echo "Injecting fish-ai secrets from 1Password..."
          ${pkgs._1password-cli}/bin/op inject -i "$TEMPLATE" -o "$CONFIG"
          echo -n "$TEMPLATE_HASH" > "$CONFIG.hash"
        fi
      ''
    );
  };
}
