{
  description = "A Bun-based project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    bun2nix.url = "github:nix-community/bun2nix";
  };

  outputs =
    inputs@{ self, ... }:
    let
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      bun2nix = inputs.bun2nix.packages.${system}.default;
      # Read package.json and extract version
      packageJson = builtins.fromJSON (builtins.readFile ./package.json);
      # Shared shell variable block for deduplication
      sharedVars = ''
        PLUGIN_DIR="$HOME/.config/opencode/plugin"
        TARGET="$PLUGIN_DIR/opencode-background.js"
        TARGET_DIR="$PLUGIN_DIR/opencode-background"
      '';
    in
    {
      packages.${system} = {
        default = bun2nix.mkDerivation {
          pname = "opencode-background";
          version = packageJson.version;  # Use extracted version
          src = ./.;

          bunDeps = bun2nix.fetchBunDeps {
            bunNix = ./bun.nix;
          };

          buildPhase = ''
            bun run build
          '';

          installPhase = ''
            mkdir -p $out
            cp -r dist/ README.md CHANGELOG.md package.json LICENSE $out/
          '';
        };

        install = pkgs.writeShellApplication {
          name = "install-opencode-background";

          runtimeInputs = [ pkgs.coreutils ];

          text = ''
            ${sharedVars}
            SRC_OPENCODE_BACKGROUND_DIR="${
              self.packages.${system}.default
            }"
            SRC_INDEX="$SRC_OPENCODE_BACKGROUND_DIR/dist/index.js"

            echo "Installing OpenCode Background plugin..."

            mkdir -p "$PLUGIN_DIR"

            if [ -f "$SRC_INDEX" ]; then
              cp -f "$SRC_INDEX" "$TARGET"

              # Only chmod if the directory exists
              if [[ -d "$TARGET_DIR" ]]; then
                chmod -R u+w "$TARGET_DIR"
              fi
              mkdir -p "$TARGET_DIR"
              cp -rf "$SRC_OPENCODE_BACKGROUND_DIR"/* "$TARGET_DIR/"
              echo "✅ Plugin installed as $TARGET"
              echo "✅ Plugin information installed as \"$TARGET_DIR/\""
              echo "   OpenCode will load it automatically on next start/reload."
            else
              echo "Error: Built index.js not found! Build may have failed."
              exit 1
            fi
          '';
        };

        uninstall = pkgs.writeShellApplication {
          name = "uninstall-opencode-background";

          runtimeInputs = [ pkgs.coreutils ];

          text = ''
            ${sharedVars}

            echo "Uninstalling OpenCode Background plugin..."

            if [ -f "$TARGET" ]; then
              chmod -R u+w "$TARGET"
              rm "$TARGET"
              echo "✅ Removed $TARGET"
            else
              echo "Plugin file not found: $TARGET"
            fi

            if [[ -d "$TARGET_DIR" ]]; then
              chmod -R u+w "$TARGET_DIR"
              rm -rf "$TARGET_DIR"
              echo "✅ Removed $TARGET_DIR"
            else
              echo "Plugin directory not found: $TARGET_DIR"
            fi

            echo "   Restart or reload OpenCode to unload the plugin."
          '';
        };
      };

      apps.${system} = {
        install = {
          type = "app";
          program = "${self.packages.${system}.install}/bin/install-opencode-background";
        };

        uninstall = {
          type = "app";
          program = "${self.packages.${system}.uninstall}/bin/uninstall-opencode-background";
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          bun
          nodejs
          mise
          bun2nix
          inotify-tools
        ];

        shellHook = ''
          echo "Starting bun.lock watcher (inlined)..."

          # Flag to prevent duplicate stop messages
          STOPPING=false

          # === Helpers ===
          get_sha() {
            if [[ -f "$1" ]]; then
              sha256sum "$1" | awk '{print $1}'
            else
              echo "absent"
            fi
          }

          print_external_warning() {
            local event="$1"
            echo "⚠️  WARNING: bun.nix was $event externally!"
            echo "   bun.nix is an auto-generated file derived from bun.lock."
            echo "   Do NOT edit, create, or delete it manually."
            echo "   To change dependencies, use 'bun add', 'bun remove', etc."
          }

          generate_bun_nix_to_temp() {
            local temp="$1"
            if ! bun2nix -l bun.lock -o "$temp"; then
              echo "Error: bun2nix failed to generate output."
              return 1
            fi
            return 0
          }

          sync_bun_nix() {
            local trigger_msg="''${1:-}"
            local quiet="''${2:-false}"

            if [[ -f bun.lock ]]; then
              local temp=$(mktemp) || return 1

              if ! generate_bun_nix_to_temp "$temp"; then
                rm -f "$temp"
                return 1
              fi

              local expected_sha=$(get_sha "$temp")
              local current_sha=$(get_sha bun.nix)

              if [[ "$expected_sha" == "$current_sha" ]]; then
                rm -f "$temp"
                [[ "$quiet" == false ]] && echo "$trigger_msg""bun.nix is already up-to-date with bun.lock."
              else
                if [[ "$current_sha" == "absent" ]]; then
                  [[ "$quiet" == false ]] && echo "$trigger_msg""bun.lock present → generating new bun.nix..."
                else
                  [[ "$quiet" == false ]] && echo "$trigger_msg""Differences detected → updating bun.nix..."
                fi
                mv "$temp" bun.nix
              fi
            else
              if [[ -f bun.nix ]]; then
                [[ "$quiet" == false ]] && echo "$trigger_msg""No bun.lock found → removing stale bun.nix..."
                rm -f bun.nix
              fi
            fi
          }

          echo "Checking initial state..."
          sync_bun_nix "" false

          # Background watcher subshell
          (
            set +euo pipefail
            set -m

            handle_bun_nix() {
              local event="$1"
              local current_sha=$(get_sha bun.nix)
              sync_bun_nix "" true
              local updated_sha=$(get_sha bun.nix)
              if [[ "$current_sha" != "$updated_sha" ]]; then
                print_external_warning "$event"
                echo "   External changes detected and corrected."
              fi
            }

            inotifywait -m -q --format "%e %f" \
              -e create -e delete -e modify -e moved_to -e moved_from \
              . |
            while IFS=' ' read -r event file; do
              case "$file" in
                "bun.lock")
                  echo "bun.lock was $event – syncing bun.nix to current state..."
                  sync_bun_nix "" false
                  ;;
                "bun.nix")
                  handle_bun_nix "$event"
                  ;;
              esac
            done
          ) &
          WATCHER_PID=$!
          echo "Bun.lock watcher running in background (PID $WATCHER_PID)."

          # Clean shutdown: group kill + simple pkill fallback (no complex quoting)
          trap 'if ! $STOPPING; then STOPPING=true; echo "Stopping bun.lock watcher..."; kill -TERM -"$WATCHER_PID" 2>/dev/null || true; pkill inotifywait 2>/dev/null || true; fi' EXIT TERM INT
        '';
      };
    };
}
