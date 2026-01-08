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
      src = pkgs.lib.cleanSource ./.;
    in
    {
      packages.${system} = {
        default = bun2nix.mkDerivation {
          pname = "opencode-background";
          version = packageJson.version;
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
            SRC_OPENCODE_BACKGROUND_DIR="${self.packages.${system}.default}"
            SRC_INDEX="$SRC_OPENCODE_BACKGROUND_DIR/dist/index.js"

            echo "Installing OpenCode Background plugin..."

            mkdir -p "$PLUGIN_DIR"

            if [ -f "$SRC_INDEX" ]; then
              cp -f "$SRC_INDEX" "$TARGET"

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
          LOG_FILE="''${PWD}/bun-watcher.log"

          log() {
            local msg="$*"
            if [[ -n "$msg" ]]; then
              printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S.%N')" "$msg" >> "$LOG_FILE"
            else
              printf '\n' >> "$LOG_FILE"
            fi
          }

          echo "bun.lock watcher active — all messages are logged to:"
          echo "    $LOG_FILE"
          echo "Use \`tail -f $LOG_FILE\` to watch live."

          log "=================================================="
          log "OpenCode Background – Development Shell Session"
          log "Project:   $(basename "$PWD")"
          log "Directory: $PWD"
          log "Started:   $(date '+%Y-%m-%d %H:%M:%S.%N %Z')"
          log "User:      $USER@$HOSTNAME"
          log "Nix shell PID: $$"
          log "=================================================="
          log ""
          log "bun.lock watcher session started"
          log "=================================================="
          log ""

          STOPPING=false

          get_sha() {
            if [[ -f "$1" ]]; then
              sha256sum "$1" | awk '{print $1}'
            else
              echo "absent"
            fi
          }

          print_external_warning() {
            local event="$1"
            log "⚠︎ WARNING: bun.nix was $event externally!"
            log "  bun.nix is an auto-generated file derived from bun.lock."
            log "  Do NOT edit, create, delete it manually."
            log "  To change dependencies, use 'bun add', 'bun remove', etc."
          }

          generate_bun_nix_to_temp() {
            local temp="$1"
            if ! bun2nix -l bun.lock -o "$temp"; then
              log "Error: bun2nix failed to generate output."
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
                [[ "$quiet" == false ]] && log "$trigger_msg""bun.nix is already up-to-date with bun.lock."
              else
                if [[ "$current_sha" == "absent" ]]; then
                  [[ "$quiet" == false ]] && log "$trigger_msg""bun.lock present → generating new bun.nix..."
                else
                  [[ "$quiet" == false ]] && log "$trigger_msg""Differences detected → updating bun.nix..."
                fi
                mv "$temp" bun.nix
              fi
            else
              if [[ -f bun.nix ]]; then
                [[ "$quiet" == false ]] && log "$trigger_msg""No bun.lock found → removing stale bun.nix..."
                rm -f bun.nix
              fi
            fi
          }

          cleanup_watcher() {
            if ! $STOPPING; then
              STOPPING=true
              log "Stopping bun.lock watcher..."
              kill $INOTIFY_PID 2>/dev/null || true
              kill $LOOP_PID 2>/dev/null || true
              rm -f "$FIFO" 2>/dev/null || true
            fi
          }

          log "Checking initial state..."
          sync_bun_nix "" false

          FIFO=$(mktemp -u)
          mkfifo "$FIFO"


          if [[ $- == *i* ]]; then
            echo "Interactive nix develop session detected – starting persistent bun.lock watcher with cleanup on exit"
            inotifywait -m -q --format "%e %f" \
              -e create -e delete -e modify -e moved_to -e moved_from \
              . > "$FIFO" 2>/dev/null &
          else
            echo "Non-interactive nix develop --command detected – starting bun.lock watcher with 60s timeout"
            timeout 60 inotifywait -m -q --format "%e %f" \
              -e create -e delete -e modify -e moved_to -e moved_from \
              . > "$FIFO" 2>/dev/null &
          fi

          INOTIFY_PID=$!
          log "Bun.lock watcher running (inotifywait PID $INOTIFY_PID)."

          (
            set +euo pipefail
            set -m

            exec 3< "$FIFO"

            handle_bun_nix() {
              local event="$1"
              local current_sha=$(get_sha bun.nix)
              sync_bun_nix "" true
              local updated_sha=$(get_sha bun.nix)
              if [[ "$current_sha" != "$updated_sha" ]]; then
                print_external_warning "$event"
                log "  External changes detected and corrected."
              fi
            }

            while IFS=' ' read -r event file; do
              case "$file" in
                "bun.lock")
                  log "bun.lock was $event – syncing bun.nix to current state..."
                  sync_bun_nix "" false
                  ;;
                "bun.nix")
                  handle_bun_nix "$event"
                  ;;
              esac
            done <&3

            exec 3<&-
          ) &
          LOOP_PID=$!
          log "Bun.lock watcher loop running (PID $LOOP_PID)."

          trap cleanup_watcher EXIT TERM

          log "bun.lock watcher fully initialized."
        '';
      };

      checks.${system} =
        let
          sharedNativeBuildInputs = self.devShells.${system}.default.buildInputs ++ [
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.procps
          ];
          sharedSetup = ''
            set -euo pipefail

            tmp=$(mktemp -d)
            trap "rm -rf $tmp" EXIT

            cp -r ${src}/. $tmp/project
            chmod -R u+w $tmp/project
            cd $tmp/project

            rm -f bun-watcher.log

            # Start the watcher
            export HOME=/tmp
            export USER=nixbld
            export HOSTNAME=build
            export PATH="${self.inputs.bun2nix.packages.${system}.default}/bin:$PATH"
            ${self.devShells.${system}.default.shellHook}

            # Wait for init
            for i in {1..30}; do
              if grep -q "bun.lock watcher fully initialized." bun-watcher.log; then
                break
              fi
              sleep 1
            done
          '';
          makeWatcherTest =
            name: testBody:
            pkgs.runCommand "${name}-test" { nativeBuildInputs = sharedNativeBuildInputs; } ''
              ${sharedSetup}
              ${testBody}
            '';
        in
        {
          watcher-init = makeWatcherTest "watcher-init" ''
            # Wait for initialization
            for i in {1..30}; do
              if grep -q "bun.lock watcher fully initialized." bun-watcher.log; then
                echo "✅ Watcher initialized successfully"
                touch $out
                exit 0
              fi
              sleep 1
            done

            echo "❌ Watcher failed to initialize"
            cat bun-watcher.log
            exit 1
          '';

          watcher-external-delete = makeWatcherTest "watcher-external-delete" ''
            # Test external deletion
            rm -f bun.nix
            for i in {1..30}; do
              if grep -q "External changes detected and corrected." bun-watcher.log && [ -f bun.nix ]; then
                echo "✅ External delete handled correctly"
                    touch $out
                exit 0
              fi
              sleep 1
            done

            echo "❌ External delete not handled"
            cat bun-watcher.log
            exit 1
          '';

          watcher-corruption = makeWatcherTest "watcher-corruption" ''
            # Test corruption
            echo "# corrupted" >> bun.nix
            for i in {1..30}; do
              if grep -q "External changes detected and corrected." bun-watcher.log && ! grep -q "# corrupted" bun.nix; then
                echo "✅ Corruption handled correctly"
                    touch $out
                exit 0
              fi
              sleep 1
            done

            echo "❌ Corruption not handled"
            cat bun-watcher.log
            exit 1
          '';

          watcher-file-move = makeWatcherTest "watcher-file-move" ''
            # Test file move
            mkdir move-bun-here
            mv bun.nix move-bun-here/
            for i in {1..30}; do
              if grep -q "External changes detected and corrected." bun-watcher.log && [ -f bun.nix ]; then
                echo "✅ File move handled correctly"
                    rm -rf move-bun-here
                touch $out
                exit 0
              fi
              sleep 1
            done

            echo "❌ File move not handled"
            cat bun-watcher.log
            rm -rf move-bun-here
            exit 1
          '';
        };
    };
}
