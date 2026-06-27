# Архитектура проекта

Проект предоставляет NixOS-конфигурацию для zapret2 — DPI-обхода блокировок РКН.

## Структура

```
├── flake.nix              # Входная точка: flake-parts, inputs, outputs
│                           #  - v2fly/domain-list-community (YouTube-домены)
│                           #  - itdoginfo/allow-domains (Russia/outside-raw.lst)
│                           #  - nixpkgs/nixos-unstable (zapret2 пакет)
├── config/
│   ├── default.nix         # Основная конфигурация: services.zapret2.rules
│   │                        # 6 профилей: http, global-tls, youtube, mtproto, quic, discord
│   └── lists/
│       ├── ipset-exclude.txt     # Приватные IP (исключение из всех правил)
│       ├── local-exclude.txt     # Ручное дополнение доменов (одна строка = один домен)
│       └── pvd-dog-ipset.txt     # IP-подсети РФ-провайдеров (CI-автообновление)
├── modules/
│   └── nixos.nix           # NixOS-модуль: опции, systemd-сервис, iptables
├── scripts/
│   └── update-pvd-dog.sh   # Скачивает JSON из russia-no-vpn-list,
│                            #  извлекает IP-подсети, пишет в pvd-dog-ipset.txt
├── tests/
│   └── integration.nix     # NixOS integration test: YouTube, rutracker.org, HTTPS
├── .github/workflows/
│   ├── flake-update.yml          # nix flake update → коммит в master (раз в неделю)
│   └── update-exclude-lists.yml  # update-pvd-dog.sh → коммит в master (раз в сутки)
└── AGENTS.md               # Правила для AI-агентов
```

## Профили zapret2 (config/default.nix)

Профили проверяются по порядку, **первый совпавший — применяется**.

| # | Имя       | Фильтр           | Стратегия                                    | Исключения                                |
|---|-----------|------------------|----------------------------------------------|------------------------------------------|
| 1 | http      | TCP/80           | multidisorder:pos=2                          | outside-raw.lst, local-exclude, 2 ipset    |
| 2 | global-tls| TCP/443 + TLS     | fake SNI=www.vk.com + multisplit:pos=2       | outside-raw.lst, local-exclude, 2 ipset    |
| 3 | youtube   | TCP/443+TLS+youtube домены | fake SNI=google.com + multidisorder | — (только YouTube)                       |
| 4 | mtproto   | L7=mtproto        | fake + ip_ttl=5 + tcp_md5                    | —                                        |
| 5 | quic      | UDP/443 + QUIC    | fake_default_quic:repeats=6                  | outside-raw.lst, local-exclude, pvd-dog    |
| 6 | discord   | UDP/50000-50100   | fake:blob=0x00:repeats=3                     | —                                        |

## Система исключений

Три источника доменов/IP, исключаемых из DPI-обхода:

| Файл                        | Источник                                   | Обновление    | Используется как  |
|-----------------------------|--------------------------------------------|---------------|-------------------|
| Russia/outside-raw.lst      | itdoginfo/allow-domains (flake input)      | nix flake update | --hostlist-exclude |
| config/lists/local-exclude.txt | Ручное редактирование (домены)           | Вручную        | --hostlist-exclude |
| config/lists/pvd-dog-ipset.txt | russia-no-vpn-list (IP подсети РФ-провайдеров) | CI раз в сутки | --ipset-exclude    |

**Порядок проверки в каждом профиле:** exclude → include. Если домен/IP в exclude — пакет не обрабатывается, падает в следующий профиль.

## CI/CD

- `flake-update` — по воскресеньям `nix flake update` и коммит flake.lock в master
- `update-exclude-lists` — ежедневно скачивает russia-no-vpn-list, извлекает IP-подсети, коммитит в master

## Сборка

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

Интеграционный тест (`nix build .#checks.x86_64-linux.integration-test`) запускается вручную — AI-агентам запрещено в AGENTS.md.
