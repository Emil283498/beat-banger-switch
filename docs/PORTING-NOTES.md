# Porting notes — AI / developer handoff

> Публичная, очищенная версия исходного handoff-документа. Абсолютные пути с
> машины автора заменены на плейсхолдеры вида `<...>`. В репозитории нет ни
> кода игры, ни её ресурсов.
>
> Beat Banger © bun fun. Применяйте эти правки только к собственной легальной
> копии игры.

---

# Beat Banger → Nintendo Switch (homebrew): полный проектный документ

> Документ для следующего AI/разработчика, который продолжит проект.
> Составлен 09.11.2026. Описывает цель, ограничения, текущее состояние, все
> правки, известные проблемы и точные команды.
>
> **Рабочая копия проекта:** `<project root>\game`
> **Готовая сборка для SD:** `<project root>\out\beat-banger\switch\beat-banger`
> **Оригинал на рабочем столе НЕ ТРОГАТЬ:** `<your legally-owned Beat Banger folder>`

---

## 0. TL;DR для следующего AI

1. Порт уже собран: движок Godot 4.7.2 → `beat-banger.nro` (66 118 762 Б),
   ресурсы → `beat-banger.pck` (392 382 912 Б, 10.11.2026 — видео 720p/30).
2. Игра запускается на Mariko (V2/Lite/OLED) под Atmosphère **только в титульном
   режиме** (зажать R при запуске любой игры → hbmenu).
3. Сохранения, моды и HTTPS-онлайн уже пропатчены в GDScript; движок для этого
   пересобирать **не нужно**.
4. Самая вероятная причина вылета «после окончания уровня» — финальное видео
   (`final_video` = `climax.webm`, ffmpeg на Switch нет). Это уже исправлено:
   используется заранее сконвертированный `.ogv` или видео отключается.
5. Отдельно остаётся неподтверждённым вылет на экране **Game Over** (проигрыш).
   Для него в сборку встроен «чёрный ящик» — `dados\depuracao.log`.
6. Нужно получить от пользователя логи после теста и читать их (раздел 12).
7. Обновлять сборку можно послойно: `data\` копированием, `beat-banger.pck`
   переэкспортом, `beat-banger.nro` только при изменении движка/порта.
8. `dados\` (сохранения) при обновлениях **никогда не удалять и не перезаписывать**.

---

## 1. Цель и требования пользователя

Цель: перенести *Beat Banger* (декомпилированный Godot-проект) на Nintendo Switch
homebrew (`.nro`, Atmosphère, Mariko) и сделать рабочими:

- **сохранения** (прогресс, настройки, резервные копии);
- **моды** (браузер модов bbmods, скачивание, установка, запуск);
- **онлайн-функции** (список модов, обложки, скачивание, новости Steam).

Дословные требования пользователя (сохранить смысл):

> «у меня после окончания уровня вылетела игра при тесте это во первых а во вторых
> как мне в будующем обновлять игру если появится новое что то и нету сохранений»

> «а сохранения работают?» → «а сделай так что бы работали моды» →
> «напиши md файл про проект всё надо написать для другой ai» →
> «кароче смотри надо сделать так что бы работали сохранения работали моды и онлайн функции»

---

## 2. Жёсткие правила (не нарушать)

1. **Не изменять оригинал** `<your legally-owned Beat Banger folder>`.
   Вся работа — только в `<project root>\game` и в выходной папке.
2. **Не распространять/не выкладывать игровые ресурсы.** `data\` и `.pck`
   содержат copyrighted-контент bun fun. Передавать только пользователю.
3. **Только WSL1.** Docker/WSL2, BIOS, admin, перезагрузка — исключены.
4. **Не прерывать сборку движка (scons).** `.sconsign5.dblite` пишется только при
   успешном завершении; прерывание ломает инкрементальную сборку.
5. **Не трогать `dados\` на SD** при обновлениях — это сохранения пользователя.
6. **WSL-команды запускать из файлов-скриптов**, а не инлайном со сложными
   `$var`/кавычками (в этой среде они регулярно ломаются). Пример:
   `wsl.exe -d Ubuntu -u root -- bash <repo>/scripts/wsl/build-godot.sh`.
7. **Не пересобирать движок без необходимости.** Почти всё (сохранения, моды,
   TLS, видео) решается в GDScript/PCK.

---

## 3. Машина и окружение

| Компонент | Путь / значение |
|---|---|
| Хост | Windows, пользователь `<user>` |
| WSL | WSL1, Ubuntu, пользователь `root` |
| devkitPro | `/opt/devkitpro` (devkitA64 + libnx + switch-mesa) |
| Исходники движка | `<godot source>` |
| Версия движка | Godot **4.7.2** (форк `calosguilherme/godot-switch-nro`) |
| Рендер | OpenGL / GL Compatibility (Mesa), **без Vulkan** |
| Godot на ПК | `<Godot 4.7.2 console exe>` |
| ffmpeg на ПК | `<ffmpeg.exe>` (8.1.1, есть libtheora/libvorbis) |
| Готовый ELF движка | `<godot source>/bin/godot.switch.template_release.arm64` (62 462 664 Б) |
| SDK/сборка скрипты | `<repo>/scripts/wsl\build-godot.sh`, `<repo>/scripts/wsl\finalizar.sh`, `<repo>/scripts/wsl\empacotar-nativo.sh` |
| Экспорт PCK | `<project root>\exportar-pck.ps1` |
| Конвертер видео модов | `<project root>\converter-videos-mods.ps1` |

Ключевые особенности `OS_Switch` (порт):

- `get_executable_path()` берёт путь `.nro` из `argv[0]`.
- `user://` = **папка рядом с `.nro`** + `/dados`
  (`OS_Switch::get_user_data_dir`), например `sdmc:/switch/beat-banger/dados`.
- `OS.execute()` и `OS.shell_open()` на Switch недоступны/не работают.
- `OS.move_to_trash()` наследует базовый `OS` и возвращает `FAILED`.
- `OS.get_name()` → `"Switch"`.
- Процессор: 3 доступных ядра из 4.
- В лог каждые 5 с пишется `[switch] pulso: ...` (heap/время), а игра дополнительно
  пишет свой `dados\depuracao.log` каждые 2 с.
- HOME/сон: порт ловит уход фокуса (`foco_mudou` + sentinela) и ставит игру на
  паузу; полагаться на это как на гарантию всё равно не стоит.

---

## 4. Карта путей

```
<project root>\
├─ game\                         ← рабочая копия декомпилированного проекта
│  ├─ project.godot              ← автолоады, [network] tls override, [gspot]
│  ├─ export_presets.cfg         ← пресет "Switch" (include *.crt, exclude data/)
│  ├─ cacert.crt                 ← CA-бандл (225 076 Б) для HTTPS на Switch
│  ├─ src\                       ← GDScript игры (все порт-правки здесь)
│  ├─ addons\gspot\gsclient.gd   ← Switch-заглушка WebSocket-клиента
│  ├─ version\                   ← версия игры
│  └─ _editor_scripts\ ...
│
├─ out\beat-banger\switch\beat-banger\   ← ГОТОВАЯ СБОРКА ДЛЯ SD
│  ├─ beat-banger.nro            ← движок + иконка/NACP (66 118 762 Б)
│  ├─ beat-banger.pck            ← ресурсы/код (392 382 912 Б)
│  ├─ data\                      ← ресурсы Steam-версии (~520 МБ, НЕ в .pck)
│  └─ dados\                     ← сохранения/настройки (создаёт игра; не трогать)
│
├─ disabled_extensions\          ← вынесенные godotsteam, discord-rpc-gd
├─ exportar-pck.ps1
├─ converter-videos-mods.ps1
├─ import-final.log / export-final.log
└─ PROJETO-PARA-IA.md            ← этот файл
```

На SD должно быть ровно так:

```
sdmc:/switch/beat-banger/
  beat-banger.nro
  beat-banger.pck
  data/
  dados/        ← сохранения пользователя
```

---

## 5. Сборка: три независимых слоя

| Слой | Что это | Как обновляется |
|---|---|---|
| `beat-banger.nro` | движок Godot + иконка + NACP | пересборка движка (редко) |
| `beat-banger.pck` | код игры, сцены, ресурсы проекта | переэкспорт PCK |
| `data\` | распакованные ресурсы Steam-версии (~520 МБ) | копирование |
| `dados\` | сохранения, настройки, кэш шейдеров | **никогда не трогать** |

Почему `data\` лежит рядом, а не в `.pck`:

- 520 МБ распакованных файлов (видео `.ogv`, звуки `.ogg`, картинки) удобнее
  обновлять копированием и они не раздувают PCK.
- В `export_presets.cfg` стоит
  `exclude_filter="data/*, data/**/*, gdre_export.log, structure.txt, _editor_scripts/*"`.
- Игра читает их через `Files.get_data_path()` =
  `OS.get_executable_path().get_base_dir().path_join("data")`.

Важно: `.nro` и `.pck` независимы (`binary_format/embed_pck=false`), поэтому при
обновлении только PCK **`.nro` менять не нужно**.

---

## 6. Движок: сборка и упаковка

### 6.1. Флаги порта

`<godot source>/platform/switch/detect.py`:

```python
"arch": "arm64"
"target": "template_release"
"vulkan": False
"opengl3": True
"lto": "full"                 # но в реальной сборке передаём lto=none
"module_theora_enabled": True # ВАЖНО: видео Theora включено
"module_mbedtls_enabled": True
"module_enet_enabled": True
"module_websocket_enabled": False   # ← WebSocketPeer отсутствует
"builtin_certs": False              # ← нет встроенных CA, нужен cacert.crt
# выключены: mono, openxr, webxr, mobile_vr, camera, upnp, webrtc, raycast,
#            lightmapper_rd, betsy, glslang, jolt, csg, text_server_adv
```

### 6.2. Сборка (WSL1)

```powershell
wsl.exe -d Ubuntu -u root -- bash <repo>/scripts/wsl/build-godot.sh
```

Скрипт:

```bash
export DEVKITPRO=/opt/devkitpro
export DEVKITA64=/opt/devkitpro/devkitA64
export PATH="/opt/devkitpro/tools/bin:/opt/devkitpro/devkitA64/bin:$PATH"
cd <godot source>
scons platform=switch target=template_release -j2 lto=none
```

Результат: `bin/godot.switch.template_release.arm64`.
Время на этом ПК: ~1 ч 45 мин. `lto=none` выбран, чтобы сборка была стабильнее.

### 6.3. Упаковка `.nro`

```powershell
wsl.exe -d Ubuntu -u root -- bash <repo>/scripts/wsl/finalizar.sh
```

`finalizar.sh` вызывает `empacotar-nativo.sh`:

```bash
nacptool --create "Beat Banger" "homebrew" "1.0.0" "$NACP"
elf2nro "$ELF" "$OUT" --icon=icone.jpg --nacp="$NACP" --romfsdir="$ROMFS"
```

romfs (`<project root>\out\.work\romfs`):

- `icone.jpg` — иконка;
- `abertura.rgba` — заставка (1280×720×4);
- `versao.txt` — версия (7 байт).

Новый NACP/иконка или версия — только через `finalizar.sh`
(версия задаётся строкой `"1.0.0"`).

Проверка `.nro`:

```powershell
wsl.exe -d Ubuntu -u root -- bash <repo>/scripts/wsl/verificar-nro.sh
```

Текущий `.nro`: 09.11.2026 не менялся, 66 118 762 Б, NACP «Beat Banger» /
«homebrew» / «1.0.0».

---

## 7. PCK: экспорт и проверка

### 7.1. Экспорт

```powershell
powershell -ExecutionPolicy Bypass -File <project root>\exportar-pck.ps1
```

Что делает скрипт:

1. `godot --headless --path <project root>\game --import`
2. `godot --headless --path ... --export-pack "Switch" <dst>.novo.pck`
3. Проверяет индекс PCK:
   - нет ни одной записи `data/`;
   - есть `cacert.crt`.
4. `Move-Item` → `beat-banger.pck`.

Требования/тонкости:

- Временный путь **должен заканчиваться на `.pck`** (`<dst>.novo.pck`).
- Пресет: `platform="Linux"`, `custom_features="switch"`,
  `export_filter="all_resources"`, `include_filter="*.crt"`,
  `exclude_filter` (см. выше), `binary_format/embed_pck=false`,
  `binary_format/architecture="arm64"`.
- Предупреждения `UID duplicate detected` и `Unrecognized UID` — безобидны.

### 7.2. Формат PCK 4.4+ (факты)

- Магия `GDPC` в байтах 0x00.
- `file_base` — u64 по смещению 0x18.
- `dir_offset` — u64 по смещению 0x20 (индекс в **конце** файла).
- По `dir_offset`: `u32 count`, затем записи:
  `u32 path_len` + `path` (UTF-8, с padding нулями) + `u64 offset` +
  `u64 size` + `16` байт md5 + `u32 flags`.
- **Пути в индексе хранятся без `res://`**
  (`pck_packer.cpp`: `trim_prefix("res://")`).

Текущий PCK (10.11.2026, после перекодирования видео в 720p/30):

- размер `392 382 912` Б (374,2 МиБ);
- записей в индексе `3183`;
- `cacert.crt` присутствует;
- записей `data/` нет;
- 9 файлов `assets/video/*.ogv` (attract-ролики грузятся в рантайме);
- в `project.binary` есть
  `network/tls/certificate_bundle_override = res://cacert.crt`.

Быстрая проверка индекса (PowerShell) — то же, что делает скрипт:

```powershell
$p="...\beat-banger.pck"
$fs=[IO.File]::OpenRead($p)
$head=New-Object byte[] 40; [void]$fs.Read($head,0,40)
$dir=[BitConverter]::ToUInt64($head,32)
$len=[int]($fs.Length-$dir); $buf=New-Object byte[] $len
$fs.Position=$dir; $fs.Read($buf,0,$len) | Out-Null
$qtd=[BitConverter]::ToUInt32($buf,0); $pos=4; $cert=$false; $data=$false
for($i=0;$i -lt $qtd;$i++){
  $pl=[BitConverter]::ToUInt32($buf,$pos); $pos+=4
  $c=[Text.Encoding]::UTF8.GetString($buf,$pos,$pl).TrimEnd([char]0)
  $pos+=$pl+36
  if($c -eq "cacert.crt"){$cert=$true}
  if($c.StartsWith("data/")){$data=$true}
}
$fs.Dispose(); "qtd=$qtd cert=$cert data=$data"
```

---

## 8. `user://`, сохранения и надёжность

### 8.1. Где лежат сохранения

`user://` = `sdmc:/switch/beat-banger/dados` (см. `OS_Switch::get_user_data_dir`).

Типичное содержимое `dados\`:

```
game.sav            ← основной сейв (ConfigFile, секция [save] data)
game.sav.bak1..3    ← резервные копии (ротация)
settings.ini        ← язык, громкость, mods_path и т.п.
cloud_mods.sav      ← локальный список id модов ("облако" — заглушка)
depuracao.log       ← трассировка текущего запуска (диагностика)
logs\beatbanger.log ← обычный лог игры
mesa_cache\         ← кэш шейдеров (можно удалить)
```

### 8.2. Что изменено в `SaveManager.gd`

Файл: `game\src\autoload\SaveManager.gd`

- **Прямая запись** `ConfigFile.save(user://game.sav)` вместо `tmp + rename`.
  На FAT/exFAT `rename` поверх существующего файла ненадёжен, поэтому от него
  отказались.
- Резервные копии делаются **копированием** (`DirAccess.copy`), не `rename`:
  - `game.sav.bak2 → game.sav.bak3`
  - `game.sav.bak1 → game.sav.bak2`
  - `game.sav → game.sav.bak1`
- Бэкапы обновляются только если основный сейв в этой сессии **успешно
  загрузился** (`_primary_save_loaded`), чтобы не затереть хорошие копии пустым
  состоянием.
- `_backups_allowed` включается, когда есть реальный прогресс (`_has_progress()`).
- Легаси `game.sav.bak` мигрирует в `game.sav.bak1` копированием.
- `game.sav.tmp` удаляется, если остался от старых версий.
- Восстановление при старте: `game.sav.tmp` → `game.sav.bak` →
  `game.sav.bak1..3`, отсортированные по времени изменения (свежие первыми).
- Если сейв существует, но не читается и ни один бэкап не подошёл —
  `_save_blocked = true`: игра **не сохраняет**, чтобы не уничтожить данные.
- `validate_save()` вызывает `save_game()` после нормализации данных.
- В `clear_save()` и удалении модов добавлены fallback-удаления, потому что
  `OS.move_to_trash` на Switch возвращает `FAILED`.

Трассировка записи (в `dados\depuracao.log`):

```
save: inicio (...)
save: copia user://game.sav -> user://game.sav.bak1 erro=0
save: direto (user://game.sav) erro=0, existe=true, tamanho=NNN
save: fim; arquivos em user:// = ...
```

Если видите `erro` ≠ 0 — писать не удалось (нет места, карта только для чтения,
повреждена ФС).

### 8.3. Перенос сохранений

Скопировать **всю папку `dados\`** на другую карту/консоль. Ничего внутри
переименовывать не нужно.

### 8.4. Диагностический флаг `sem_save`

Пустой файл `dados\sem_save` полностью выключает запись (для A/B-тестов).

### 8.5. Язык интерфейса

В коде значение по умолчанию — **английский**
(`src/autoload/SettingsManager.gd`: `{"key": "locale", "default": "en"}`).
Фактический язык берётся из `dados\settings.ini`:

```ini
[settings]
data={
"locale": "en"
}
```

- Если файла `settings.ini` нет — игра создаст его со значением `en`.
- Сменить язык можно в игре: меню паузы (`game_pause` = кнопка `+`/Start или Esc)
  → `Language` → English / Русский / Español / 日本語 / 한국인 / Deutsch.
  Обработчик — `src/prefabs/HotMenu/locale_button.gd`, он пишет `settings.ini`.
- Русский в готовой папке появлялся только потому, что в `settings.ini` лежало
  `"locale": "ru"`. Чтобы вернуть английский — заменить на `"en"` или удалить
  `settings.ini` (тогда подставится `en`). Пересобирать PCK для этого не нужно.
- Автоопределения языка системы в игре нет: `OS_Switch::get_locale()` система
  умеет, но `SettingsManager` его не использует (только `settings.ini`).

---

## 9. Моды: путь, установка, FAT, видео

### 9.1. Путь модов

`Files.get_mods_path()`:

```gdscript
return ProjectSettings.globalize_path(SettingsManager.settings_data.get("mods_path", "user://mods"))
```

То есть по умолчанию: `user://mods` → `<папка .nro>/dados/mods`
= `sdmc:/switch/beat-banger/dados/mods`.

`Files.validate_mod_path()` создаёт папку при старте (`Global.gd`).

### 9.2. Как ставится мод

1. Браузер модов (`src/scenes/Mods/...`, `mod_database.gd`) запрашивает
   `https://api.beatbanger.com/api/mods`.
2. `mod_pack_mod_extractor.gd` скачивает zip в
   `<mods>\<имя папки>.zip` (`HTTPRequest.set_download_file`).
3. `Files.extract_all_from_zip` распаковывает в `<mods>\<имя папки>`.
4. `write_download_config` пишет `download.cfg`, обложка сохраняется как
   `bbmods_thumb.webp`.
5. Zip удаляется: `OS.move_to_trash` → при `FAILED` вызывается
   `DirAccess.remove_absolute`.

Папка мода должна содержать `act.cfg` (и/или `config\...`), иначе
`GameManager.get_act_datatree` её не увидит.

### 9.3. FAT/exFAT-совместимость

`DownloadableMod.install_folder_name()`:

- `title.validate_filename().strip_edges().rstrip(".")`;
- пустое имя → `id` или `"mod"`;
- удаляются хвостовые точки/пробелы (FAT их не любит);
- ограничение 96 символов;
- финальная страховка — `"mod"`.

Удаление «всех модов» (`mod_settings_controller.delete_all_mods`) и
`finish_extracting` получили fallback на реальное удаление через
`Files.remove_dir_recursive`.

### 9.4. Видео модов: `.webm` → `.ogv`

Проблема: движок собран с Theora, но **без VP8/VP9 и без ffmpeg**. Игра грузит
видео только как `.ogv` (`Assets.load_asset`, `AssetManager.get_requested_asset_folder`).
Моды часто кладут `.webm`.

Решение (два уровня):

1. **На ПК** — `<project root>\converter-videos-mods.ps1`:
   - рекурсивно ищет `*.webm` в папке модов;
   - создаёт рядом `X.ogv` (libtheora, 720p, без звука, `-q:v 8`);
   - переписывает ссылки `X.webm` → `X.ogv` в `.cfg` **того же мода**;
   - по умолчанию оригинальный `.webm` оставляет;
   - флаги: `-Forcar`, `-ApagarWebm`, `-SemReescreverConfig`.

   Примеры:

   ```powershell
   powershell -ExecutionPolicy Bypass -File <project root>\converter-videos-mods.ps1
   powershell -ExecutionPolicy Bypass -File <project root>\converter-videos-mods.ps1 -Pasta "E:\switch\beat-banger\dados\mods"
   ```

2. **В игре (рантайм-страховка)** — даже если конфиг мода всё ещё говорит
   `.webm`:
   - `AssetManager.get_requested_asset_folder()` и
     `ce_get_requested_asset_folder()` подменяют `webm` → `ogv`;
   - `Assets.load_asset()` и `load_cutscene_asset()` при `.webm` пытаются
     загрузить соседний `.ogv`;
   - `Assets.get_asset()` и `get_cutscene_asset()` ищут ключ `.ogv`, если
     запрошен `.webm`;
   - `game_outro_video.gd` для финального видео: если есть `.ogv` — играет его,
     если нет — **отключает видео**, а не пытается запускать ffmpeg.

Итог: мод с `.webm` без конвертации не падает — просто останется без видео.
После конвертации видео работает.

### 9.5. Ограничение

Конвертация «на лету» на самой консоли невозможна: нет ffmpeg и нет `OS.execute`.
Конвертировать нужно на ПК (скрипт выше) и копировать `.ogv` на карту.

---

## 10. Онлайн: bbmods + HTTPS

### 10.1. Что должно работать

- Список модов: `https://api.beatbanger.com/api/mods?limit=200`.
- Карточка мода: `/api/mods/{id}`.
- Обложка: `/api/mods/{id}/thumbnail`.
- Скачивание: `/api/mods/{id}/download`.
- Новости Steam: `https://api.steampowered.com/ISteamNews/...`.

### 10.2. Почему HTTPS раньше не работал и как исправлено

Движок собран с `module_mbedtls_enabled=True`, но `builtin_certs=False`.
`Crypto::load_default_certificates("")` пытается взять системные CA, которых на
Switch нет → TLS не может проверить сертификат.

Исправление **без пересборки движка**:

1. Скопирован CA-бандл движка
   `thirdparty/certs/ca-bundle.crt` → `<project root>\game\cacert.crt`
   (225 076 Б).
2. В `project.godot`:

   ```ini
   [network]

   tls/certificate_bundle_override="res://cacert.crt"
   ```

3. В `export_presets.cfg`: `include_filter="*.crt"`, чтобы файл попал в PCK.
4. `Crypto::load_default_certificates` читает `res://cacert.crt` при старте игры
   (`main.cpp`), и `TLSOptions::client()` без явной цепочки использует эти CA.

Требования для успешного TLS:

- интернет на консоли;
- **правильные дата/время на Switch** (иначе проверка срока сертификата
  провалится — это не баг порта);
- в PCK есть `cacert.crt` (проверяется скриптом).

### 10.3. Что не работает

- **Steam Workshop / Steam Cloud** — заглушки.
- **Discord RPC** — заглушка.
- **Игрушки/Intiface (WebSocket)** — движок без WebSocket; клиент заменён
  заглушкой (раздел 11).
- Кнопки «открыть папку», «открыть сайт», «сообщить об ошибке» используют
  `OS.shell_open`, а он на Switch возвращает `ERR_UNAVAILABLE` — просто ничего
  не произойдёт.
- Ввод текста (поиск в браузере модов, IP/порт Intiface) может быть недоступен:
  экранная клавиатура Switch не подключена.

### 10.4. Что смотреть в логе при проблемах с сетью

```
Mod list request failed (result %d, HTTP %d)
Mod list request could not start
Mod list response was not valid JSON
SSL module failed to initialize!
```

`result` — код `HTTPRequest.Result` (0 = success), второй — HTTP-код.
Если `SSL module failed to initialize!` — не загрузился `cacert.crt`.
Если TLS-ошибка при верном пакете — проверьте часы консоли.

---

## 11. Заглушки нативных расширений (важно при обновлении проекта)

### 11.1. Steam / Discord

- Аддоны `godotsteam` и `discord-rpc-gd` вынесены в
  `<project root>\disabled_extensions`.
- `SteamManager.gd` — заглушка: `steam_active=false`, все методы пустые,
  `ach_unlock`/`set_stat` и т.п. ничего не делают.
- `DiscordMananger.gd` — заглушка.

### 11.2. GSpot / Intiface

Файл: `game\addons\gspot\gsclient.gd` полностью заменён на Switch-безопасную
заглушку.

Причина: движок собран с `module_websocket_enabled=False`, поэтому класса
`WebSocketPeer` нет. Оригинальный клиент падал при импорте:

```
Parse Error: Identifier "WebSocketPeer" not declared
```

Это ломало автолоад `GSClient` и каскадом — `ToyControlManager.gd`,
`UiButton.gd`, `downloadable_mod.gd`, `mod_pack_mod_extractor.gd`, то есть
**весь браузер модов**. После замены `--import` чистый.

Заглушка сохраняет публичный API (константы, сигналы, `start/stop/scan_*`,
`get_devices`, `send_*`, `stop_*`, `_get_feature_duration` и т.д.), но:

- `start()` возвращает `ERR_UNAVAILABLE` и пишет предупреждение;
- устройств нет, команды — no-op;
- `send_linear()` — `await get_tree().process_frame`, чтобы не сломать
  `ToyControlManager`.

Итог: меню игрушек открывается, но устройства не подключаются. Это осознанно.

---

## 12. Вылет после уровня / Game Over: что уже сделано и как читать логи

### 12.1. Два разных пути

1. **Уровень пройден** (`level_passed`) → `src/scenes/game_outro_video.gd`
   запускает финальное видео `Config.asset["final_video"]`.
   В базовых данных часто стоит `"final_video": "climax.webm"`, при этом файла
   `climax.webm` нет, а ffmpeg на Switch нет. Старый код вызывал
   `OS.execute` на несуществующий бинарник и/или пытался играть несуществующий
   `.ogv` — вероятная причина падения сразу после конца уровня.

   **Исправлено:** если есть соседний `.ogv` — играем его; если нет — видео
   отключается, игра продолжает переход уровня. Никакого ffmpeg.

2. **Уровень провален** → `src/prefabs/GameOver.gd` (экран «УРОВЕНЬ ПРОВАЛЕН»).
   Здесь может быть отдельный вылет: анимация, звук, сохранение, смена сцены.
   Причина пока не подтверждена; для неё встроена трассировка.

### 12.2. «Чёрный ящик»

- `dados\depuracao.log` — пишется через `Trace.t()` с `flush()` после каждой
  строки, поэтому переживает жёсткое падение.
- В начале файла: реальный путь `user://` и список файлов с размерами.
- Каждые 2 с: `pulso: quadro=... cena=... objetos=... video=... MiB fps=...`.
- Трассируются: смена сцены, экран Game Over, сохранение.
- Обычный лог: `beat-banger.log` (stdout движка).

### 12.3. Как читать

- Если `pulso` идёт до последней строки, а потом резко обрывается → **краш**
  (SIGSEGV/abort). Последняя строка — точка падения.
- Если `pulso` пропал, но игра «висит» → **зависание**, не краш.
- Последняя строка `gameover: ...` показывает, на каком шаге упало.
- Строки `save: ...` показывают, писался ли сейв.
- Строка `video: ...` показывает, отключилось ли финальное видео.

### 12.4. A/B-флаги (пустые файлы в `dados\`)

| Файл | Что отключает |
|---|---|
| `sem_animacao_go` | анимацию экрана Game Over |
| `sem_audio_go` | звуки экрана Game Over |
| `sem_transicao` | экран загрузки (прямая смена сцены) |
| `sem_save` | запись сохранений |

Удалите файл, чтобы вернуть обычное поведение.

### 12.5. Что запросить у пользователя

1. `switch\beat-banger\dados\depuracao.log`
2. `switch\beat-banger\beat-banger.log`
3. `switch\beat-banger\beat-banger.anterior.log` (если есть)
4. Список `switch\beat-banger\dados\` (имя + размер), особенно `game.sav` и
   `game.sav.bak1..3`
5. Свежую папку из `atmosphere\crash_reports\` (если есть)

### 12.6. Если краш останется

- Сначала проверить **успешное** завершение уровня (final video теперь
  отключён/ogv).
- Затем — Game Over с флагами по одному.
- В крайнем случае добавить в порт обработчик SIGSEGV с backtrace и пересобрать
  движок (~1 ч 45 мин).

---

## 13. Как обновлять игру в будущем

### Сценарий A. Обновились только ресурсы Steam (`data\`)

1. Скопировать новую `data\` из Steam поверх старой в
   `<project root>\out\beat-banger\switch\beat-banger\data`.
2. Скинуть `data\` на карту поверх.
3. `dados\` не трогать.

Если новый код ссылается на новые файлы — нужен сценарий B.

### Сценарий B. Обновилась сама игра (новые уровни/механики/сцены)

1. Декомпилировать новую версию в **новую** папку (GDRE Tools).
2. Перенести порт-правки (список ниже).
3. `powershell -ExecutionPolicy Bypass -File <project root>\exportar-pck.ps1`
4. Убедиться, что проверка прошла: `3183` (или новое число) записей,
   `cert=True`, `data=False`.
5. Скопировать `beat-banger.pck` на карту. `dados\` не трогать.

**Порт-правки, которые обязательно перенести:**

| Файл | Что там |
|---|---|
| `addons\gspot\gsclient.gd` | Switch-заглушка (без WebSocketPeer) |
| `src\autoload\SteamManager.gd` | заглушка Steam |
| `src\autoload\DiscordMananger.gd` | заглушка Discord |
| `src\autoload\SaveManager.gd` | прямая запись + копийные бэкапы + fallback-удаление |
| `src\autoload\AssetManager.gd` | `webm → ogv` в путях ассетов |
| `src\autoload\SceneManager.gd` | трассировка + флаг `sem_transicao` |
| `src\class\files.gd` | `get_data_path`, `get_mods_path`, `remove_dir_recursive`, zip |
| `src\class\assets.gd` | `webm → ogv` fallback, ключи ассетов |
| `src\class\ffmpeg.gd` | `is_available()`, no-op на Switch |
| `src\scenes\game_outro_video.gd` | `.ogv`/отключение финального видео |
| `src\scenes\mod_pack_mod_extractor.gd` | удаление без `move_to_trash` |
| `src\scenes\Mods\mod_settings_controller.gd` | удаление всех модов без `move_to_trash` |
| `src\prefabs\downloadable_mod.gd` | FAT-safe имя папки |
| `src\prefabs\GameOver.gd` | трассировка + флаги |
| `src\class\trace.gd` | «чёрный ящик» |
| `src\autoload\Global.gd` | `Files.validate_mod_path()` |
| `project.godot` | `[network] tls/...`, `[gspot]`, автолоады |
| `export_presets.cfg` | пресет Switch, `include_filter="*.crt"`, `exclude_filter` |
| `cacert.crt` | CA-бандл (225 076 Б) |
| `disabled_extensions\` | вынесенные godotsteam/discord-rpc-gd |

### Сценарий C. Обновился движок Godot или порт

1. Обновить `platform/switch` в `<godot source>`.
2. `wsl.exe -d Ubuntu -u root -- bash <repo>/scripts/wsl/build-godot.sh`
3. `wsl.exe -d Ubuntu -u root -- bash <repo>/scripts/wsl/finalizar.sh`
4. Версия — в `<repo>/scripts/wsl\finalizar.sh` (строка `"1.0.0"`).
5. Проверка — `verificar-nro.sh`.

**Правило:** `dados\` не удалять и не перезаписывать ни в одном сценарии.

---

## 14. Шпаргалка команд

```powershell
# Импорт ресурсов (проверка скриптов)
& "<Godot 4.7.2 console exe>" --headless --path "<project root>\game" --import

# Экспорт PCK + проверка
powershell -ExecutionPolicy Bypass -File <project root>\exportar-pck.ps1

# Сборка движка (WSL1, ~1 ч 45 мин)
wsl.exe -d Ubuntu -u root -- bash <repo>/scripts/wsl/build-godot.sh

# Упаковка NRO
wsl.exe -d Ubuntu -u root -- bash <repo>/scripts/wsl/finalizar.sh

# Проверка NRO
wsl.exe -d Ubuntu -u root -- bash <repo>/scripts/wsl/verificar-nro.sh

# Конвертация видео модов
powershell -ExecutionPolicy Bypass -File <project root>\converter-videos-mods.ps1 -Pasta "E:\switch\beat-banger\dados\mods"

# Список файлов движка
wsl.exe -d Ubuntu -u root -- ls -l <godot source>/bin/
```

Запуск игры на консоли:

1. Главное меню Switch → курсор на любой игре.
2. Зажать **R** и, не отпуская, нажать **A**.
3. В hbmenu выбрать `beat-banger.nro`.

Из альбома доступно ~400 МБ памяти — игра, скорее всего, упадёт.

---

## 15. Известные ограничения порта

- Разрешение 1280×720; смена разрешения/режима окна в настройках бесполезна
  (в доке система растягивает).
- Видео Theora декодируется на CPU; на слабом ARM может лагать. В настройках
  есть пропуск кассет/снижение качества.
- Нет ввода текста (экранная клавиатура Switch не подключена).
- Нет вибрации.
- Steam, Discord, Workshop, облако — заглушки.
- Игрушки/Intiface не работают (нет WebSocket).
- `OS.shell_open` не работает (кнопки «открыть папку/сайт» молчат).
- FFmpeg на консоли нет; конвертация видео — только на ПК.
- Язык системы определяется (`get_locale` через `setInitialize`), но игра всё
  равно может брать язык из `settings.ini`.
- Скриншоты/открытие папок через `OS.shell_open` не работают.
- На FAT32 файл не может быть > 4 ГБ; текущие файлы меньше, но при росте
  сборки это надо учитывать (лучше exFAT).

---

## 16. Чек-лист проверки после установки

- [ ] Игра запускается в титульном режиме, без экрана ошибки.
- [ ] Главное меню, музыка, заставка.
- [ ] `dados\` создан, внутри `settings.ini`, `game.sav` (или появится после
      первого сохранения).
- [ ] Пройти уровень **до конца** и убедиться, что нет вылета (финальное видео
      отключено/ogv).
- [ ] Проиграть уровень (Game Over), нажать Retry и Give up.
- [ ] `dados\depuracao.log` содержит `pulso`, `save: direto ... erro=0`,
      `gameover: ...`.
- [ ] `dados\game.sav.bak1..3` появляются после реального прогресса.
- [ ] Открыть браузер модов: список загружается (`3183`-подобный ответ API —
      это число записей PCK, не модов; у API `total≈1778`).
- [ ] Обложки модов грузятся.
- [ ] Скачать и установить небольшой мод; он появляется в списке и запускается.
- [ ] Мод с `.webm`: после конвертера на ПК видео играет.
- [ ] Часы Switch выставлены верно (для HTTPS).
- [ ] При вылете — собрать логи из раздела 12.5.

---

## 17. Быстрые факты (чтобы не искать заново)

- Движок: **Godot 4.7.2**, OpenGL, ARM64, `lto=none`, `-j2`.
- Theora: **включена** (`module_theora_enabled=True`).
- WebSocket: **выключен** (`module_websocket_enabled=False`).
- mbedTLS: **включён**, `builtin_certs=False`, CA через `res://cacert.crt`.
- `user://` = `<папка .nro>/dados`.
- `data\` = `<папка .nro>/data` (~520 МБ, вне PCK).
- PCK: 392 382 912 Б (374,2 МиБ), индекс 3183, пути в индексе без `res://`.
- NRO: 66 118 762 Б, NACP «Beat Banger» / «homebrew» / «1.0.0».
- Switch: 1280×720, vsync включён, `Engine.max_fps = 60` (принудительно в
  `SettingsManager.set_resolution/set_vsync/set_fps`).
- Видео на Switch: 720p, максимум 30 fps (скрипт `otimizar-videos-switch.ps1`).
- `.nro` и `.pck` независимы (`embed_pck=false`).
- Моды: `<nro dir>/dados/mods`.
- Сейв: `game.sav`, бэкапы `game.sav.bak1..3`.
- API модов: `https://api.beatbanger.com/api`.
- ffmpeg на ПК: `<ffmpeg.exe>` (libtheora есть).
- Конвертер: `<project root>\converter-videos-mods.ps1`.
- Экспорт PCK: `<project root>\exportar-pck.ps1`.
- Сборка движка: `<repo>/scripts/wsl\build-godot.sh`; упаковка: `<repo>/scripts/wsl\finalizar.sh`.

---

## 18. Что делать дальше (по приоритету)

0. Если обновились видео игры или `data\` — прогнать
   `otimizar-videos-switch.ps1` (720p/30) и переэкспортировать PCK, иначе
   вернутся фризы (раздел 19).
1. Передать пользователю **только новый `beat-banger.pck`** (и инструкции),
   `dados\` не трогать.
2. Получить логи после теста: успешное завершение уровня + Game Over.
3. Прочитать `depuracao.log` (раздел 12.3) и определить: краш или зависание,
   на каком шаге.
4. Если финальное видео всё ещё причастно — проверить, что в `data`/моде нет
   `climax.webm` без `.ogv`; при необходимости сконвертировать на ПК.
5. Если падает Game Over — A/B-флаги (`sem_animacao_go`, `sem_audio_go`,
   `sem_transicao`, `sem_save`).
6. Проверить онлайн: список модов, обложки, скачивание; при TLS-ошибке —
   часы консоли.
7. Проверить сохранения: `game.sav` и `.bak1..3` появляются, прогресс
   переносится копированием `dados\`.
8. Только если действительно нужно — добавить SIGSEGV-handler и пересобрать
   движок.

---

## 19. Производительность: видео и меню на Switch

### 19.1. Почему тормозило

Theora в Godot декодируется **на CPU в главном потоке**:
`VideoStreamPlaybackTheora::update()` → `video_write()` → конвертация YUV→RGBA
(`yuv420_2_rgb8888`) → `texture->update()` (полная загрузка кадра в GPU).
Стоимость примерно равна `ширина × высота × fps`:

| источник | было | стало |
|---|---|---|
| фон главного меню (3 ролика) | 1920×1080 @60 → 124 Мпикс/с | 1280×720 @30 → 27,6 Мпикс/с |
| attract-ролики (4) | 1920×1080 @30 → 62 Мпикс/с | 1280×720 @30 → 27,6 Мпикс/с |
| заставки | 1920×1080 @60 → 124 Мпикс/с | 1280×720 @30 → 27,6 Мпикс/с |

То есть нагрузка на декодер упала в 2,25–4,5 раза. Видео в `data\` уже было
720p и ≤30 fps, кроме двух файлов `bb_vol_2\cathy_e2\video\*ClimaxBG.ogv`
(1080p) — их тоже перекодировали.

Дополнительные причины (не связанные с видео):

1. `SettingsManager.set_resolution()` применял сохранённое разрешение
   (по умолчанию **1920×1080**) и на Switch → корневой viewport рисовался в
   1080p, а потом ужимался в поверхность 1280×720: лишние 2,25× пикселей на
   каждый кадр, во всех меню и в игре.
2. `window/vsync/vsync_mode=0` в `project.godot`, а `Engine.max_fps` вообще
   не выставлялся (безлимит): игра рисовала больше кадров, чем успевала, и
   отбирала CPU у декодера.
3. Шейдер хроматической аберрации (`src/shaders/chromatic_abberation.gdshader`)
   объявлял `hint_screen_texture, filter_linear_mipmap`, хотя читал LOD 0 —
   каждый кадр генерировалась mip-цепочка полного экрана. Шейдер вставлен в
   `main_menu`, `game`, `loading`, `cutscene`, `extras`, `level_select`,
   `scene_viewer`, `sound_test`.
4. `attract_screen.gd` держал **четыре `preload`** роликов по 70–120 МБ —
   сотни мегабайт RAM и многосекундная пауза при входе в экран.
5. `SceneManager` писал «пульс» в `user://depuracao.log` каждые 2 секунды с
   `flush()` — на карте памяти это микро-фриз каждые 2 секунды.

### 19.2. Что сделано

- **Видео** перекодированы на ПК скриптом `otimizar-videos-switch.ps1`:
  720p, максимум 30 fps, libtheora (`-q:v 6` для `attract_*`, `-q:v 7` для
  остальных), Vorbis `-q:a 4`. Оригиналы складываются в
  `backups\videos-1080p\<game-assets|data>\...`.
  Скрипт идемпотентен: файлы, которые уже ≤720p и ≤30 fps, пропускаются.
  Запуск:

  ```powershell
  powershell -ExecutionPolicy Bypass -File D:\BeatBangerSwitch\otimizar-videos-switch.ps1
  ```

  Проверка:

  ```powershell
  C:\ffmpeg\bin\ffprobe.exe -v error -select_streams v:0 `
      -show_entries stream=width,height,r_frame_rate -of csv=p=0 <файл.ogv>
  ```

- `SettingsManager.gd`:
  - добавлен `is_switch()`;
  - `set_resolution()` на Switch всегда ставит **1280×720**;
  - `set_vsync()` на Switch всегда включает vsync;
  - `set_fps()` на Switch ставит `Engine.max_fps = 60`, и теперь он
    **вызывается** в `_ready()` (раньше функция существовала, но её никто не
    вызывал);
  - заодно исправлен `set_chromatic_abberation()`: он читал
    `reduce_motion` вместо `chromatic_abberation`.
- `project.godot`: `window/vsync/vsync_mode=1`.
- `chromatic_abberation.gdshader`: `filter_linear_mipmap` → `filter_linear`.
- `attract_screen.gd`: вместо `preload` — список путей и `load()` по одному
  ролику; предыдущий поток обнуляется перед загрузкой следующего.
- `SceneManager.gd`: «пульс» включается только если в `dados\` есть файл
  `pulso` (диагностика вылетов — по требованию).
- `converter-videos-mods.ps1`: моды тоже ограничиваются 720p и 30 fps
  (параметр `-MaxFps`, `0` отключает ограничение).
- `export_presets.cfg`: `include_filter="*.crt,*.ogv"` — видео теперь грузятся
  в рантайме через `load()`, и экспортёр обязан их паковать.
  `exportar-pck.ps1` проверяет, что в PCK лежат 9 файлов `assets/video/*.ogv`.

### 19.3. Что ожидать

- Меню и переходы перестают «дёргаться»: 60 fps с vsync, без лишних 1080p
  пикселей и без mip-генерации каждый кадр.
- Видео (меню, attract, заставки, финальные ролики) играет ровно; на сложных
  сценах возможны редкие пропуски кадров — это CPU-декодер, а не баг.
- Экран attract теперь появляется без многосекундной паузы.

### 19.4. Что можно сделать ещё (если понадобится)

1. Декодировать Theora в отдельном потоке (правка `modules/theora/video_stream_theora.cpp`
   + `VideoStreamPlayer`) — самый большой, но и самый рискованный выигрыш.
2. Отключить хроматическую аберрацию на Switch (убирает копию экрана и 3
   выборки на кадр): в `SettingsManager.set_chromatic_abberation()` принудительно
   `false`. Меняет внешний вид (виньетка), поэтому по умолчанию не включено.
3. Понизить фон меню до 960×540 — на 720p-экране разница почти незаметна.

---

## 20. Правовая заметка

Порт неофициальный. Игровые ресурсы (`data\`, `beat-banger.pck`, музыка, видео,
изображения) принадлежат правообладателям *Beat Banger* (bun fun). Не
публиковать, не выкладывать в общий доступ и не распространять эти файлы.
Передавать сборку только владельцу копии игры.
