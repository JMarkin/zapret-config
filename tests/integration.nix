{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  nixosModule = import ../modules/nixos.nix;
  configOutput = import ../config { inherit lib pkgs inputs; };
in
pkgs.testers.nixosTest {
  name = "zapret2-config-integration";

  nodes = {
    machine = { ... }: {
      virtualisation.vlans = [ ];
      networking.useDHCP = true;
      imports = [ nixosModule configOutput ];

      boot.kernelModules = [ "nfnetlink_queue" ];
      environment.systemPackages = with pkgs; [ yt-dlp curl tcpdump bind.dnsutils ];
    };
  };

  testScript = ''
    def dump_diagnostics():
        print("  === DIAGNOSTICS ===")
        for cmd, desc in [
            ("systemctl is-active zapret2", "Service status"),
            ("systemctl status zapret2 --no-pager", "Systemd status"),
            ("journalctl -u zapret2 --no-pager -o cat", "Journal"),
            ("pgrep -a nfqws2", "Process check"),
            ("iptables -L -n -t mangle 2>/dev/null | grep NFQUEUE", "iptables NFQUEUE"),
            ("lsmod | grep nfnetlink_queue", "NFQUEUE module"),
            ("ip route get 1.1.1.1", "Routing check"),
            ("ip addr show 2>/dev/null || ip addr", "Network interfaces"),
            ("cat /etc/zapret2/nfqws0.conf", "Config"),
        ]:
            status, out = machine.execute(cmd)
            print(f"  [{desc}] exit={status}\n{out}")

    start_all()

    # Phase 0: Service health
    print("=== Phase 0: Service health ===")
    try:
        machine.wait_for_unit("zapret2", timeout=30)
    except:
        dump_diagnostics()
        raise
    dump_diagnostics()
    machine.sleep(2)

    # Phase 1: Russian sites excluded from DPI — must work without bypass
    print("=== Phase 1: Russian exclude (must NOT be desync'd) ===")

    # DNS diagnostics
    for cmd, desc in [
        ("cat /etc/resolv.conf", "resolv.conf"),
        ("nslookup esia.gosuslugi.ru 2>&1 || dig esia.gosuslugi.ru +short", "esia lookup"),
        ("nslookup gosuslugi.ru 2>&1 || dig gosuslugi.ru +short", "gosuslugi lookup"),
        ("curl -v --max-time 10 https://esia.gosuslugi.ru 2>&1", "esia curl verbose"),
    ]:
        status, out = machine.execute(cmd)
        print(f"  [{desc}] exit={status}\n{out[:500]}")

    for url in ["https://esia.gosuslugi.ru"]:
      status = machine.succeed(
          "curl -s -o /dev/null -w '%{http_code}' -L --max-time 15 " + url
      )
      print(f"  {url}: HTTP {status.strip()}")
      assert status.strip() in ["200", "301", "302"], \
          f"{url}: HTTP {status.strip()} — exclude broken?"

    # Phase 2: Basic HTTP (DPI bypass required)
    for url in ["https://youtube.com", "https://rutracker.org"]:
      status = machine.succeed(
          "curl -s -o /dev/null -w '%{http_code}' --max-time 15 " + url
      )
      print(f"  {url}: HTTP {status.strip()}")
      assert status.strip() not in ["000", ""], f"{url} unreachable"

    # Phase 3: YouTube video metadata
    title = machine.succeed(
        'yt-dlp --simulate --print title '
        '"https://youtube.com/watch?v=dQw4w9WgXcQ"'
    ).strip()
    print(f"  Video title: {title}")
    assert len(title) > 0, "Empty title — YouTube metadata blocked?"

    # Phase 4: Video segment URL
    video_url = machine.succeed(
        'yt-dlp -f best --get-url '
        '"https://youtube.com/watch?v=dQw4w9WgXcQ"'
    ).strip()
    print(f"  Video URL: {video_url[:80]}...")
    assert "googlevideo.com" in video_url, \
        "Video URL doesn't point to googlevideo.com"

    # Phase 5: Download first 1MB of the segment
    result = machine.succeed(
        "curl -r 0-1048576 --max-time 30 -s -o /tmp/video_segment.mp4 "
        "-w '%{http_code}' '" + video_url + "'"
    ).strip()
    print(f"  Segment download: HTTP {result}")
    assert result == "206", f"Expected 206, got {result}"
    size = machine.succeed("stat -c%s /tmp/video_segment.mp4").strip()
    print(f"  Downloaded: {size} bytes")
    assert int(size) > 1024, "Downloaded less than 1KB — data not flowing"

    # Phase 6: inkstory.net (excluded in local-exclude.txt)
    print("=== Phase 6: inkstory.net (must NOT be desync'd) ===")
    for url in ["https://inkstory.net"]:
      status = machine.succeed(
          "curl -s -o /dev/null -w '%{http_code}' -L --max-time 15 " + url
      )
      print(f"  {url}: HTTP {status.strip()}")
      assert status.strip() in ["200", "301", "302"], \
          f"{url}: HTTP {status.strip()} — exclude broken?"

    print("=== ALL CHECKS PASSED ===")
  '';
}
