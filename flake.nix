{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;
      stdenv = pkgs.stdenv;
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

        build = stdenv.mkDerivation {
          pname = "opencode-background-build";
          version = "0.2.0-alpha.2";
          src = ./.;
          buildInputs = [ pkgs.nodejs ];
          buildPhase = ''
            # npm install
            npm run build
          '';
          installPhase = ''
            mkdir -p $out
            cp -r dist $out/
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
