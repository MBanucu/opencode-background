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
          # bun() {
          #   command bun "$@"
          #   if [[ $1 == "install" || $1 == "add" || $1 == "remove" || $1 == "uninstall" ]]; then
          #     echo "Updating bun.nix..."
          #     bun2nix -l bun.lock -o bun.nix
          #   fi
          # }

          # Start file watcher for bun.lock changes
          if [[ -f bun.lock ]]; then
            echo "Starting bun.lock watcher..."
            inotifywait -m -e modify bun.lock | while read; do
              echo "bun.lock changed, updating bun.nix..."
              bun2nix -l bun.lock -o bun.nix
            done &
            WATCHER_PID=$!
            trap "kill $WATCHER_PID" EXIT
          fi
        '';
      };
    };
}
