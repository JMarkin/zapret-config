update-pvd-dog:
    nix develop --command bash scripts/update-pvd-dog.sh

update-flake:
    nix flake update

# Run integration test
# AGENTS: DO NOT run this — ask user first per AGENTS.md
test:
    nix build .#checks.x86_64-linux.integration-test
