{
  description = "Zapret2 DPI bypass configuration";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dlc.url = "github:v2fly/domain-list-community";
    dlc.flake = false;
    allow-domains.url = "github:itdoginfo/allow-domains";
    allow-domains.flake = false;
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
      ];
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        devShells = {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              zapret2
              nixd
              nodejs
            ];
          };
        };
      };
      flake = {
        homeManagerModules.default = import ./config { inherit inputs; };
      };
    };
}
