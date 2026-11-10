{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rss-builder.url = "path:/Users/rodion/src/rss-builder";
    rss-builder.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rss-builder }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      pandoc = pkgs.stdenvNoCC.mkDerivation {
        pname = "pandoc";
        version = "3.8.3";
        src = pkgs.fetchzip {
          url = "https://github.com/jgm/pandoc/releases/download/3.8.3/pandoc-3.8.3-arm64-macOS.zip";
          hash = "sha256-DlkbIY8PBd2HPLMWvLibca/voMujF1J2ZSlre+if32c=";
        };
        installPhase = ''
          mkdir -p $out
          cp -r . $out
        '';
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pandoc ];
      };
      packages.${system}.default = pkgs.writeShellApplication {
        name = "build-site";
        runtimeInputs = [
          pandoc
          rss-builder.packages.${system}.default
        ];
        text = ''
          cd posts
          for f in *.md; do
            name="''${f%.md}"
            echo "processing $name"
            pandoc \
              -V homeurl=file:///Users/rodion/src/site/index.html \
              --template post-template.pd \
              -s -c style.css \
              --syntax-highlighting my.theme \
              "$name.md" -o "$name.html"
          done
          cd ..

          rss-builder \
            --dir=posts \
            --base-url=https://rodio.codeberg.page/ \
            --title="Rodion's Blog"
        '';
      };
    };
}
