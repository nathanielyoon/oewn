{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs =
    { self, nixpkgs }:
    {
      packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          version = "2025-plus";
          files = "${builtins.placeholder "out"}/dict";
          dictd = "${builtins.placeholder "out"}/share/dictd";
        in
        {
          oewn = pkgs.stdenvNoCC.mkDerivation {
            pname = "oewn";
            inherit version;
            src = pkgs.fetchzip {
              url = "https://en-word.net/static/english-wordnet-${version}.zip";
              hash = "sha256-0Fxb9oWXh5/B5XeHxzPFlJANxyXNr0I7VKtrT4h3Xhc=";
            };
            installPhase = ''
              mkdir -p ${files}
              for data_file in data.*; do
                  for file in "''${data_file//data/index}" "$data_file"; do
                      target="${files}/''${file##*/}"
                      # Avoid errors from parsing extra trailing linefeeds.
                      tr -s '\n' <"$file" >"$target"
                  done
              done
            '';
          };
          dictdDBs.oewn = pkgs.stdenvNoCC.mkDerivation {
            pname = "dictd-db-oewn";
            inherit version;
            src = ./wordnet_structures.py;
            dontUnpack = true;
            nativeBuildInputs = [
              pkgs.python3
              pkgs.libfaketime
            ];
            installPhase = ''
              args=""
              for data_file in ${self.packages.${system}.oewn}/dict/data.*; do
                  args="$args ''${data_file//data/index} $data_file"
              done

              mkdir -p ${dictd}
              source_date=$(date --utc --date="@$SOURCE_DATE_EPOCH" '+%F %T')
              faketime -f "$source_date" python $src \
                  --outindex="${dictd}/oewn.index" \
                  --outdata="${dictd}/oewn.dict" \
                  --wn_url="https://en-word.net/" \
                  --db_desc_short="Open English WordNet" \
                  --db_desc_long="Open English WordNet (2025-plus edition), a fork of the Princeton WordNet." \
                  $args
              echo "en_US.UTF-8" >"${dictd}/locale"
            '';
          };
          default = self.packages.${system}.oewn;
        }
      );
      overlays = {
        oewn = _: prev: { oewn = self.packages.${prev.stdenv.hostPlatform.system}.oewn; };
        dictdDBs.oewn = _: prev: { oewn = self.packages.${prev.stdenv.hostPlatform.system}.dictdDBs.oewn; };
        default = self.overlays.oewn;
      };
    };
}
