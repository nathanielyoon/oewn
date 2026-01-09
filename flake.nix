{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = inputs: {
    packages = inputs.nixpkgs.lib.genAttrs inputs.nixpkgs.lib.systems.flakeExposed (system: {
      default =
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        pkgs.stdenvNoCC.mkDerivation rec {
          version = "2025-plus";
          pname = "oewn";
          src = pkgs.fetchzip {
            url = "https://en-word.net/static/english-wordnet-${version}.zip";
            hash = "sha256-0Fxb9oWXh5/B5XeHxzPFlJANxyXNr0I7VKtrT4h3Xhc=";
          };
          nativeBuildInputs = [
            pkgs.python3
            pkgs.libfaketime
            pkgs.dict
          ];
          convert = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/servers/dict/wordnet_structures.py";
            hash = "sha256-Oz50QMw/fOVaekYYIXdbq3qxQoqxIdEJtHLDCVZkQS0=";
          };
          installPhase =
            let
              files = "${builtins.placeholder "out"}/dict/data";
              dictd = "${builtins.placeholder "out"}/share/dictd";
            in
            /* bash */ ''
              # Move index and data files, squeezing repeated newlines to avoid
              # parsing errors for *.adv.
              mkdir -p ${files}
              for data_file in data*; do
                  for file in "''${data_file//data/index}" "$data_file"; do
                      target="${files}/''${file##*/}"
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

              # Compress data to .dz file.
              dictzip "${dictd}/oewn.data"
            '';
        };
    });
  };
}
