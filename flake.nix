{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs =
    { self, nixpkgs }:
    {
      packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          oewn = pkgs.stdenvNoCC.mkDerivation {
            pname = "oewn";
            version = "2025";
            src = builtins.fetchGit {
              url = "git@github.com:globalwordnet/english-wordnet.git";
              rev = "4136856654f476aca21a39b8c969a763b866dda4";
            };
            nativeBuildInputs = [
              pkgs.python3
              pkgs.python3Packages.pyyaml
              pkgs.yq-go
              pkgs.jaq
            ];
            buildPhase = ''
              mkdir -p "$out/share"

              echo "yaml -> xml"
              python3 scripts/from_yaml.py --year=2025

              echo "xml -> json"
              yq --input-format=xml --output-format=json --xml-attribute-prefix="" --xml-content-name=_ '.LexicalResource.Lexicon' wn.xml >wn.json

              echo "json -> tsv"
              # shellcheck disable=SC2016
              jaq --raw-output 'def flat: flatten | map(values | if isobject then "\(._) (\(.[keys[] | select(. != "_")]))" else . end); {
                  synsets: .Synset | map({
                      key: .id,
                      value: {
                          definition: .Definition,
                          members: .members | split(" "),
                          examples: .Example | flat
                      }
                  }) | from_entries,
                  entries: .LexicalEntry | map({
                      key: .id,
                      value: {
                          form: .Lemma.writtenForm,
                          part: {
                              n: "noun",
                              v: "verb",
                              a: "adjective",
                              r: "adverb",
                              s: "adjective satellite",
                              c: "conjunction",
                              p: "adposition",
                              x: "other",
                              u: "unknown"
                          }[.Lemma.partOfSpeech],
                          pronunciation: .Lemma.Pronunciation | flat | join("/"),
                          senses: .Sense | flatten | map(.synset)
                      }
                  }) | from_entries
              } as $root | $root.entries | to_entries[] | [
                  .value.form,
                  .value.part,
                  .value.pronunciation,
                  (.key as $id | [$root.synsets[.value.senses[]] | [
                      .definition,
                      [.members[] | $root.entries[select(. != $id)].form],
                      .examples
                  ]] | tojson)
              ] | @tsv' wn.json >"$out/share/oewn.tsv"
            '';
            installPhase = ''
              mkdir -p "$out/bin"

              cat >"$out/bin/oewn" <<EOF
              #!/usr/bin/env bash

              # shellcheck disable=SC2016
              shuf $out/share/oewn.tsv | fzf --query="\$*" --delimiter='\t' --with-nth=1 --preview-border=none --preview='
                  printf {2}
                  if [[ -n {3} ]]; then printf '\''' (%s)'\''' {3}; fi
                  printf '\'''\n\n'\'''

                  count=\$(jaq '\'''length'\''' <<<{4})
                  outer=\$((FZF_PREVIEW_COLUMNS - count / 10))
                  inner=\$((outer - 2))
                  jaq --raw-output '\'''.[] | "\(.[0])\(if .[1] | length == 0 then "" else " [\(.[1] | join(", "))]" end)\(.[2] | map("\n\(tojson)") | join(""))\n"'\''' <<<{4} | fold --spaces --width=\$FZF_PREVIEW_COLUMNS
              ' --preview-window='down,75%,wrap'
              EOF
              chmod u+x "$out/bin/oewn"
            '';
          };
          default = self.packages.oewn;
        }
      );
      overlays = {
        oewn = _: prev: { oewn = self.packages.${prev.stdenv.hostPlatform.system}.oewn; };
        default = self.overlays.oewn;
      };
    };
}
