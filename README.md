# oewn

Package wrapping [open-english-wordnet](https://en-word.net/) with
[fzf](https://github.com/junegunn/fzf).

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    oewn = {
      url = "github:nathanielyoon/oewn";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    { nixpkgs, ... }@inputs:
    {
      nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          { environment.systemPackages = [ inputs.oewn.packages.oewn ]; }
        ];
      };
    };
}
```
