{ inputs, ... }:
let
  dlc = inputs.dlc;
  allowDomains = inputs.allow-domains;
  ipsetExclude = ./lists/ipset-exclude.txt;
  ipsetExcludePvdDog = ./lists/pvd-dog-ipset.txt;
  hostlistExcludeLocal = ./lists/local-exclude.txt;
in
{ pkgs, ... }:
{
  services.zapret2 = {
    enable = true;
    configureFirewall = true;
    httpSupport = true;
    udpSupport = true;
    udpPorts = [ "443" "50000:50100" ];
  };
  services.zapret2.rules = [
    "--qnum=200"
    "--lua-init=@${pkgs.zapret2}/share/zapret2/lua/zapret-lib.lua"
    "--lua-init=@${pkgs.zapret2}/share/zapret2/lua/zapret-antidpi.lua"

    # HTTP — глобальный multidisorder + исключения
    "--new"
    "--name=http"
    "--filter-tcp=80"
    "--hostlist-exclude=${allowDomains}/Russia/outside-raw.lst"
    "--hostlist-exclude=${hostlistExcludeLocal}"
    "--ipset-exclude=${ipsetExclude}"
    "--ipset-exclude=${ipsetExcludePvdDog}"
    "--lua-desync=multidisorder:pos=2"

    # Общий TLS — VK-подмена + исключения российских доменов
    "--new"
    "--name=global-tls"
    "--filter-tcp=443"
    "--filter-l7=tls"
    "--payload=tls_client_hello"
    "--ipset-exclude=${ipsetExclude}"
    "--hostlist-exclude=${allowDomains}/Russia/outside-raw.lst"
    "--hostlist-exclude=${hostlistExcludeLocal}"
    "--ipset-exclude=${ipsetExcludePvdDog}"
    "--lua-desync=fake:blob=0x00000000:tls_mod=rnd,dupsid,sni=www.vk.com:tcp_md5"
    "--lua-desync=multisplit:pos=2"

    # YouTube — специфичная стратегия
    "--new"
    "--name=youtube"
    "--filter-tcp=443"
    "--filter-l7=tls"
    "--payload=tls_client_hello"
    "--hostlist=${dlc}/data/youtube"
    "--lua-desync=fake:blob=0x00000000:tls_mod=rnd,dupsid,sni=www.google.com:tcp_md5"
    "--lua-desync=multidisorder:pos=1,midsld"

    # Telegram MTProto
    "--new"
    "--name=mtproto"
    "--filter-l7=mtproto"
    "--payload=mtproto_initial"
    "--lua-desync=fake:blob=0x00000000:ip_ttl=5:tcp_md5"

    # QUIC (YouTube) — исключения российских доменов
    "--new"
    "--name=quic"
    "--filter-udp=443"
    "--filter-l7=quic"
    "--payload=quic_initial"
    "--hostlist-exclude=${allowDomains}/Russia/outside-raw.lst"
    "--hostlist-exclude=${hostlistExcludeLocal}"
    "--ipset-exclude=${ipsetExcludePvdDog}"
    "--lua-desync=fake:blob=fake_default_quic:repeats=6"

    # Discord/STUN
    "--new"
    "--name=discord"
    "--filter-udp=50000-50100"
    "--lua-desync=fake:blob=0x00000000:repeats=3"
  ];
}
