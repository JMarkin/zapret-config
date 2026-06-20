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
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        checks.integration-test = import ./tests/integration.nix {
          inherit pkgs inputs;
        };
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
        nixosModules.default = import ./modules/nixos.nix;
        nixosModules.config = import ./config { inherit inputs; };
      };
    };
}
