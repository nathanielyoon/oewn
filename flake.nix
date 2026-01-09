{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs =
    { self, nixpkgs }:
    {
      packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: {
        oewn =
          let
            pkgs = nixpkgs.legacyPackages.${system};
            files = "${builtins.placeholder "out"}/dict/data";
            dictd = "${builtins.placeholder "out"}/share/dictd";
            convert = pkgs.fetchurl {
              url = "https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/servers/dict/wordnet_structures.py";
              hash = "sha256-Oz50QMw/fOVaekYYIXdbq3qxQoqxIdEJtHLDCVZkQS0=";
            };
            version = "2025-plus";
          in
          pkgs.stdenvNoCC.mkDerivation {
            pname = "oewn";
            inherit version;
            src = pkgs.fetchzip {
              url = "https://en-word.net/static/english-wordnet-${version}.zip";
              hash = "sha256-0Fxb9oWXh5/B5XeHxzPFlJANxyXNr0I7VKtrT4h3Xhc=";
            };
            nativeBuildInputs = [
              pkgs.python3
              pkgs.libfaketime
              pkgs.dict
            ];
            installPhase = ''
              mkdir -p ${files}
              for data_file in data*; do
                  for file in "''${data_file//data/index}" "$data_file"; do
                      target="${files}/''${file##*/}"
                      # Avoid errors when parsing extra trailing linefeeds.
                      tr -s '\n' <"$file" >"$target"
                      args="$args $target"
                  done
              done

              # Convert to dictd-compatible format.
              mkdir -p ${dictd}
              source_date=$(date --utc --date="@$SOURCE_DATE_EPOCH" '+%F %T')
              faketime -f "$source_date" python ${convert} \
                  --outindex="${dictd}/oewn.index" \
                  --outdata="${dictd}/oewn.data" \
                  --wn_url="https://en-word.net/" \
                  --db_desc_short="Open English WordNet" \
                  --db_desc_long="Open English WordNet (2025-plus edition), a fork of the Princeton WordNet." \
                  $args
              echo "en_US.UTF-8" >"${dictd}/locale"

              # Check hash.
              cd ${builtins.placeholder "out"}
              find . -type f | sort | xargs sha256sum | sha256sum \
                  --check <(echo "2d8d434b8ef78783a94f0b6d5fc642bfc4108f9db5c25cef48b2494fac7b4298  -")

              # Compress data file.
              dictzip --keep ${dictd}/oewn.data
            '';
          };
        default = self.packages.oewn;
      });
      overlays = {
        oewn = _: prev: { oewn = self.packages.${prev.stdenv.hostPlatform.system}.oewn; };
        default = self.overlays.oewn;
      };
    };
}
