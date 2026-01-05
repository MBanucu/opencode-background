{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # Shared shell variable block for deduplication
      sharedVars = ''
        PLUGIN_DIR="$HOME/.config/opencode/plugin"
        TARGET="$PLUGIN_DIR/opencode-background.js"
        TARGET_DIR="$PLUGIN_DIR/opencode-background"
      '';
    in
    {
      packages.${system} = {
        default = pkgs.buildNpmPackage {
          pname = "opencode-background";
          version = "0.2.0-alpha.2";
          src = ./.;
          npmDepsHash = "sha256-R7EAHDF3eVnJvM21Rs1SCXUn4fcsx4tb8noYoTHJsJw=";
          nativeBuildInputs = [ pkgs.bun ];
        };

        install = pkgs.writeShellApplication {
          name = "install-opencode-background";

          runtimeInputs = [ pkgs.coreutils ];

          text = ''
            ${sharedVars}
            SRC_OPENCODE_BACKGROUND_DIR="${
              self.packages.${system}.default
            }/lib/node_modules/@mbanucu/opencode-background"
            SRC_INDEX="$SRC_OPENCODE_BACKGROUND_DIR/dist/index.js"

            echo "Installing OpenCod(e Background plugin..."

            mkdir -p "$PLUGIN_DIR"
            whoami

            if [ -f "$SRC_INDEX" ]; then
              cp -f "$SRC_INDEX" "$TARGET"

              # Only chmod if the directory exists
              if [[ -d "$TARGET_DIR" ]]; then
                chmod -R u+w "$TARGET_DIR"
              fi
              cp -rf "$SRC_OPENCODE_BACKGROUND_DIR" "$PLUGIN_DIR/"
              echo "✅ Plugin installed as $TARGET"
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

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          bun
          nodejs
        ];
      };
    };
}
