# Integration Test for zapret2 Config

Date: 2026-06-20

## Goal

Automated NixOS VM integration test that validates the zapret2 service starts
correctly and DPI bypass works for YouTube (including video segments) and
rutracker.org.

## Approach

Single NixOS test file at `tests/integration.nix`, runnable via
`nix build .#checks.<system>.integration-test` or `nix flake check`.

The test imports the existing NixOS module (`modules/nixos.nix`) and config
(`config/default.nix`) directly — no duplication of rules.

## File structure

```
tests/integration.nix    # the only new file
```

## Integration in flake.nix

```nix
perSystem = { pkgs, ... }: {
  checks.integration-test = pkgs.nixosTest (import ./tests/integration.nix {
    inherit pkgs inputs;  # inputs from outer closure (dlc, allow-domains)
  });
};
```

## Test VM Configuration

- Imports `modules/nixos.nix` (systemd unit + iptables rules)
- Imports `config/default.nix` (existing nfqws2 rules: http, global-tls,
  youtube, mtproto, quic, discord)
- Uses default `configureFirewall = true` — iptables rules are set up as in
  production
- Adds `pkgs.yt-dlp` and `pkgs.curl` to the VM environment

## Test phases

All phases run in a single `testScript`:

| Phase | What | Tool | Pass condition |
|-------|------|------|----------------|
| 0. Health | Wait for systemd unit, check journal | `systemctl`, `journalctl` | Service active, no ERROR level messages |
| 1. HTTP | Fetch youtube.com, rutracker.org | `curl --max-time 15` | Non-empty HTTP status code (not 000) |
| 2. Metadata | Fetch YouTube video info | `yt-dlp --simulate --print-title` | Non-empty title |
| 3. Video URL | Resolve best format URL | `yt-dlp -f best --get-url` | URL contains `googlevideo.com` |
| 4. Segment | Fetch first 1MB of video | `curl -r 0-1048576 --max-time 30` | HTTP 206 Partial Content, >1KB downloaded |

Test video: `dQw4w9WgXcQ` (Rick Astley — Never Gonna Give You Up), a stable,
long-lived YouTube video.

## Risks

- **No network in builder:** test requires `sandbox = false`. Documented
  requirement.
- **YouTube changes format delivery:** if `--get-url` stops returning
  `googlevideo.com`, the assertion must be updated.
- **NFQUEUE unsupported in VM:** add `boot.kernelModules = [ "xt_NFQUEUE" ]`
  if needed. NixOS kernels ship it by default.
- **QEMU user-mode networking:** TCP/UDP works, but ICMP is limited. Not a
  concern since test only uses TCP.
