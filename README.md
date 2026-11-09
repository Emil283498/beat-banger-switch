# Beat Banger — Nintendo Switch (homebrew)

![Platform](https://img.shields.io/badge/platform-Nintendo%20Switch-e60012)
![Engine](https://img.shields.io/badge/engine-Godot%204.7.2-478cbf)
![Mode](https://img.shields.io/badge/mode-Atmosph%C3%A8re%20(title)-blueviolet)
![License](https://img.shields.io/badge/license-MIT-green)

Неофициальный homebrew-порт **Beat Banger** на Nintendo Switch (`.nro`).
Движок — Godot 4.7.2 (OpenGL / GL Compatibility), собранный из форка
[`calosguilherme/godot-switch-nro`](https://github.com/calosguilherme/godot-switch-nro).

> [!IMPORTANT]
> **В репозитории только часть.** Здесь только инструменты и документация.
> Beat Banger и её ресурсы принадлежат **bun fun**. Декомпилированный код,
> папка `data/` **не распространяется, её надо достать из официальной версии**.
> Для сборки нужна легальная копия игры. Проект не связан с bun fun.

---

## Что это

Порт запускается на **Mariko** (Switch V2 / Lite / OLED) под **Atmosphère**
в титульном режиме и доводит игру до играбельного состояния:

- **сохранения** — надёжная запись на FAT/exFAT + резервные копии `game.sav.bak1..3`;
- **моды** — браузер модов bbmods, скачивание и установка прямо на консоли;
- **онлайн** — список модов, обложки, скачивание и новости по HTTPS;
- **видео** — Theora (`.ogv`) включена; `.webm` из модов конвертируется на ПК;
- **HOME/сон** — игра ставится на паузу при потере фокуса.


## Что в репозитории

```
beat-banger-switch/
├─ README.md
├─ LICENSE
├─ NOTICE.md
├─ CHANGELOG.md
├─ docs/
│  ├─ INSTALL.md          — установка на карту и первый запуск
│  ├─ UPDATING.md         — как обновлять три слоя сборки
│  ├─ TESTING.md          — проверка и диагностика вылетов
│  ├─ BUILD.md            — сборка движка и экспорт PCK
│  └─ PORTING-NOTES.md    — полная карта порт-правок (handoff)
├─ scripts/
│  ├─ exportar-pck.ps1        — импорт + экспорт + проверка .pck
│  ├─ converter-videos-mods.ps1 — .webm → .ogv для модов
│  └─ wsl/
│     ├─ build-godot.sh       — сборка движка (scons)
│     ├─ finalizar.sh         — упаковка .nro
│     ├─ empacotar-nativo.sh  — nacptool + elf2nro
│     └─ verificar-nro.sh     — проверка .nro
└─ .github/ISSUE_TEMPLATE/
```

## Требования

**Консоль**
- Mariko: Switch V2, Lite или OLED (Erista не тестировался);
- Atmosphère + hbmenu;
- microSD, желательно **exFAT** (FAT32 ограничен файлами до 4 ГБ);
- ~1.3 ГБ свободного места (`.nro` + `.pck` + `data/`).

**ПК для сборки**

## Быстрый старт

скачайте официальную версию beat banger (из неё понадобится папка data)
далее эту папку нужно поместить по пути SD:\switch\beat-banger\

## Сохранения, моды, онлайн

- **Сохранения:** `dados/game.sav` + `game.sav.bak1..3`. Запись напрямую,
  бэкапы копированием, восстановление при повреждении.
- **Моды:** `dados/mods`. Видео модов `.webm` конвертируется в `.ogv`:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\converter-videos-mods.ps1 `
      -Pasta "E:\switch\beat-banger\dados\mods"
  ```
- **Онлайн:** HTTPS работает через CA-бандл внутри PCK
  (`network/tls/certificate_bundle_override`). Нужны интернет и **верные часы**
  на консоли.

## Диагностика

Рядом с `.nro`:
- `beat-banger.log` — обычный лог;
- `dados/depuracao.log` — пошаговая трассировка (обновляется каждые 2 с);
- `dados/mesa_cache/` — кэш шейдеров (можно удалять).

Вылеты: `sdmc:/atmosphere/crash_reports/`.
Как читать логи и A/B-флаги — [`docs/TESTING.md`](docs/TESTING.md).

## Ограничения

- разрешение фиксировано 1280×720 (система растягивает в доке);
- пока что нет ввода текста (экранная клавиатура Switch не подключена);-
- Steam, Discord, Workshop, облако — заглушки;
- игрушки / Intiface (WebSocket) не работают — движок без WebSocket;
- `OS.shell_open` не работает (кнопки «открыть папку/сайт» молчат);
- ffmpeg на консоли нет — видео конвертируется только на ПК.

## Благодарности

- [Godot Engine](https://godotengine.org/) — MIT;
- [`calosguilherme/godot-switch-nro`](https://github.com/calosguilherme/godot-switch-nro) — база порта;
- [devkitPro](https://devkitpro.org/) (devkitA64, libnx, switch-mesa);
- Open code (помощник по разработке)
- **bun fun** — за саму игру Beat Banger.

## Лицензия

Код репозитория (скрипты и документация) — [MIT](LICENSE).

---

# English (short)

An unofficial **Beat Banger** homebrew port for Nintendo Switch, built with
Godot 4.7.2 (OpenGL) from
[`calosguilherme/godot-switch-nro`](https://github.com/calosguilherme/godot-switch-nro).

> [!WARNING]
> **No game content is included.** Beat Banger and its assets are © bun fun.
> This repository contains only original tooling and documentation. You must
> own a legal copy of the game. Not affiliated with or endorsed by bun fun.

**Features:** working saves (`game.sav` + `.bak1..3`), mod browser/downloads,
HTTPS online features, Theora video, HOME/sleep pause.

**Requirements:** Mariko console (V2/Lite/OLED), Atmosphère, hbmenu, exFAT SD;
Windows + Godot 4.7.2 + WSL1/devkitPro to build; ffmpeg to convert mod videos.

**Docs:** [install](docs/INSTALL.md) · [updating](docs/UPDATING.md) ·
[testing](docs/TESTING.md) · [build](docs/BUILD.md) ·
[porting notes](docs/PORTING-NOTES.md).

**Disclaimer:** for personal use only. Do not distribute the game, `.pck`,
`data/` or `.nro` builds. Beat Banger is © bun fun. Repository code is MIT.
