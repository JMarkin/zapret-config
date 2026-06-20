# zapret2-config

Nix Flake и NixOS-модуль для настройки [zapret2](https://github.com/bol-van/zaprep) — инструмента обхода DPI (Deep Packet Inspection).

## Возможности

- Установка и запуск `nfqws2` как systemd-сервиса
- Автоматическая настройка iptables-маршрутизации трафика через NFQUEUE
- Поддержка HTTP (80), HTTPS (443), UDP
- Стратегии десинхронизации для разных протоколов: TLS, Telegram MTProto, QUIC
- Исключения для доменов и IP-адресов

## Быстрый старт

```bash
nixos-rebuild switch --flake .#<hostname>
```

## Использование как NixOS-модуль

```nix
{
  imports = [ (builtins.fetchFlake "github:jmarkin/zapret-config").nixosModules.default ];

  services.zapret2 = {
    enable = true;
    configureFirewall = true;
    httpSupport = true;
    udpSupport = true;
    udpPorts = [ "443" "50000:50100" ];
    rules = [
      "--qnum=200"
      "--lua-init=@${pkgs.zapret2}/share/zapret2/lua/zapret-lib.lua"
      "--lua-init=@${pkgs.zapret2}/share/zapret2/lua/zapret-antidpi.lua"
      "--new"
      "--name=http"
      "--filter-tcp=80"
      "--lua-desync=multidisorder:pos=2"
    ];
  };
}
```

## Готовая конфигурация

В проекте есть готовый конфиг в `config/default.nix` с настройками для:

- **HTTP** — multidisorder с исключениями из списков доменов
- **TLS (HTTPS)** — подмена на VK для Instagram, Cloudflare, Google
- **YouTube** — специфичная стратегия с подменой на Google
- **Telegram MTProto** — фейковый TLS-пакет
- **QUIC** — фейковые пакеты для YouTube
- **Discord/STUN** — фейковые UDP-пакеты

Подключить готовую конфигурацию:

```nix
{
  imports = [
    (builtins.fetchFlake "github:jmarkin/zapret-config").nixosModules.default
    (builtins.fetchFlake "github:jmarkin/zapret-config").nixosModules.config
  ];
}
```

## Опции

| Опция | Тип | По умолчанию | Описание |
|-------|-----|--------------|----------|
| `enable` | bool | `false` | Включить сервис |
| `package` | package | `pkgs.zapret2` | Пакет zapret2 |
| `instance` | str | `"nfqws0"` | Имя экземпляра для конфига |
| `rules` | list of str | `[]` | Параметры командной строки nfqws2 |
| `configureFirewall` | bool | `true` | Настраивать firewall автоматически |
| `httpSupport` | bool | `true` | Маршрутизировать HTTP (порт 80) |
| `httpMode` | enum | `"first"` | Режим десинхронизации HTTP: `first` или `full` |
| `udpSupport` | bool | `false` | Включить маршрутизацию UDP |
| `udpPorts` | list of str | `[]` | Список UDP-портов для маршрутизации |
| `qnum` | int | `200` | Номер NFQUEUE |

## Зависимости

- Ядро Linux с модулем `nfnetlink_queue`
- iptables/ip6tables

