{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Karabiner-Elements rewrites karabiner.json itself whenever you touch its
  # UI, so Home Manager cannot own the file. Instead, declare only the rules we
  # care about and merge them into every profile on activation, matching on
  # `description` so a re-run replaces the rule rather than duplicating it.
  # Anything added through the UI is left in place.
  karabinerRules = [
    {
      description = "Change caps_lock to control if pressed with other keys, to escape if pressed alone.";
      manipulators = [
        {
          type = "basic";
          from = {
            key_code = "caps_lock";
            modifiers.optional = [ "any" ];
          };
          to = [ { key_code = "left_control"; } ];
          to_if_alone = [ { key_code = "escape"; } ];
        }
      ];
    }
  ];

  karabinerRulesFile = pkgs.writeText "karabiner-rules.json" (builtins.toJSON karabinerRules);

  jq = lib.getExe pkgs.jq;

  # Managed rules go first so they win over anything added through the UI.
  karabinerMerge = ''
    ($managed[0] | map(.description)) as $managedNames
    | .profiles |= map(
        .complex_modifications.rules =
          ($managed[0]
           + ((.complex_modifications.rules // [])
              | map(select(.description as $d | $managedNames | index($d) | not))))
      )
  '';
in
{
  home.activation.karabinerRules = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    karabinerConfig="${config.xdg.configHome}/karabiner/karabiner.json"
    if [[ ! -f $karabinerConfig ]]; then
      echo "karabiner: no $karabinerConfig yet; launch Karabiner-Elements once, then re-run" >&2
    elif ! merged=$(${jq} --indent 4 --slurpfile managed ${karabinerRulesFile} \
      ${lib.escapeShellArg karabinerMerge} "$karabinerConfig"); then
      echo "karabiner: $karabinerConfig is not valid JSON, leaving it alone" >&2
    elif ! ${jq} -e --argjson merged "$merged" '. == $merged' "$karabinerConfig" > /dev/null; then
      tmp=$(mktemp)
      printf '%s\n' "$merged" > "$tmp"
      run mv "$tmp" "$karabinerConfig"
      rm -f "$tmp"
      echo "karabiner: updated managed rules in $karabinerConfig" >&2
    fi
  '';

  xdg.configFile."ghostty/config".text = ''
    theme = tokyonight
    font-family = Iosevka Nerd Font Mono
    font-size = 14
    window-padding-x = 8
    window-padding-y = 8
    macos-titlebar-style = tabs
    copy-on-select = true
    shell-integration = fish
    cursor-style = bar
    cursor-style-blink = false
    background-opacity = 0.95
    background-blur-radius = 20
    unfocused-split-opacity = 0.85
    mouse-hide-while-typing = true
  '';
}
