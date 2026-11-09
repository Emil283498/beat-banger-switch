# Сборка движка и экспорт PCK

> English summary at the end.

## 1. Окружение

| Компонент | Значение |
|---|---|
| Движок | Godot **4.7.2**, форк `calosguilherme/godot-switch-nro` |
| Платформа | Switch, ARM64, OpenGL / GL Compatibility (Mesa) |
| Сборка | WSL1 (Ubuntu) или Linux, devkitPro, scons |
| Рендер | только OpenGL, **без Vulkan** |
| Godot на ПК | `Godot_v4.7.2-stable_win64_console.exe` (импорт/экспорт PCK) |

devkitPro: `devkitA64`, `libnx`, `switch-mesa`, `tools` (`nacptool`,
`elf2nro`). По умолчанию ставится в `/opt/devkitpro`.

## 2. Флаги порта (`platform/switch/detect.py`)

```python
"arch": "arm64"
"target": "template_release"
"vulkan": False
"opengl3": True
"module_theora_enabled": True      # видео Theora
"module_mbedtls_enabled": True     # HTTPS
"module_enet_enabled": True        # сеть
"module_websocket_enabled": False  # WebSocketPeer отсутствует
"builtin_certs": False             # CA через res://cacert.crt
# выключены: mono, openxr, webxr, mobile_vr, camera, upnp, webrtc, raycast,
#            lightmapper_rd, betsy, glslang, jolt, csg, text_server_adv
```

> [!IMPORTANT]
> `module_websocket_enabled=False` означает, что класса `WebSocketPeer` нет.
> Клиент GSpot/Intiface нужно заменить заглушкой, иначе импорт проекта падает
> с `Parse Error: Identifier "WebSocketPeer" not declared`. Подробности — в
> [PORTING-NOTES.md](PORTING-NOTES.md).

## 3. Сборка движка

```bash
# WSL1 / Linux
export GODOT_SRC=$HOME/godot-switch-nro-trabalho/godot
export DEVKITPRO=/opt/devkitpro

bash scripts/wsl/build-godot.sh
```

Скрипт выполняет:

```bash
scons platform=switch target=template_release -j2 lto=none
```

Переменные: `GODOT_SRC`, `DEVKITPRO`, `JOBS` (по умолчанию 2), `LTO`
(по умолчанию `none`), `TARGET`, `LOG`.

Результат: `bin/godot.switch.template_release.arm64`.
Время на среднем ПК — около **1 ч 45 мин**.

> [!WARNING]
> Не прерывайте инкрементальную сборку. Файл `.sconsign5.dblite` пишется
> только при успешном завершении; прерывание может сломать сборку.

## 4. Упаковка `.nro`

```bash
bash scripts/wsl/finalizar.sh
```

Переменные: `ELF`, `NRO`, `TITLE`, `AUTHOR`, `VERSION`, `ICON`, `ROMFS`.
Внутри вызывается `empacotar-nativo.sh`:

```bash
nacptool --create "$TITLE" "$AUTHOR" "$VERSION" "$NACP"
elf2nro "$ELF" "$NRO" --icon="$ICON" --nacp="$NACP" --romfsdir="$ROMFS"
```

romfs обычно содержит:

- `icone.jpg` — иконка 256×256;
- `abertura.rgba` — заставка 1280×720×4 (опционально);
- `versao.txt` — версия (опционально).

Проверка:

```bash
bash scripts/wsl/verificar-nro.sh ./beat-banger.nro
```

## 5. Экспорт PCK

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\exportar-pck.ps1 `
    -Projeto .\game -Destino .\out\beat-banger.pck `
    -Godot "C:\Tools\Godot472\Godot_v4.7.2-stable_win64_console.exe"
```

Что делает скрипт:

1. `godot --headless --path <projeto> --import`;
2. `godot --headless --path <projeto> --export-pack <preset> <tmp>.pck`;
3. проверяет индекс PCK:
   - нет записей `data/`;
   - есть `cacert.crt`, если он есть в проекте.

Тонкости:

- временный путь **обязан** заканчиваться на `.pck`;
- пресет экспорта: `platform="Linux"`, `custom_features="switch"`,
  `export_filter="all_resources"`, `include_filter="*.crt"`,
  `exclude_filter="data/*, data/**/*"`,
  `binary_format/embed_pck=false`, `binary_format/architecture="arm64"`;
- предупреждения `UID duplicate detected` и `Unrecognized UID` безобидны.

## 6. Формат PCK 4.4+ (для проверки)

- магия `GDPC` в байтах `0x00`;
- `file_base` — `u64` по смещению `0x18`;
- `dir_offset` — `u64` по смещению `0x20` (индекс в конце файла);
- по `dir_offset`: `u32 count`, затем записи
  `u32 path_len` + path (UTF-8) + `u64 offset` + `u64 size` +
  `16` байт md5 + `u32 flags`;
- пути в индексе хранятся **без** `res://`.

Скрипт `exportar-pck.ps1` уже реализует эту проверку.

## 7. HTTPS / сертификаты

Движок собран с `builtin_certs=False`, поэтому нужен CA-бандл:

1. положите `cacert.crt` в корень проекта (Mozilla CA bundle из Godot,
   `thirdparty/certs/ca-bundle.crt`);
2. в `project.godot`:
   ```ini
   [network]
   tls/certificate_bundle_override="res://cacert.crt"
   ```
3. в `export_presets.cfg`: `include_filter="*.crt"`.

Без этого TLS не сможет проверить сертификат. Также нужны **верные дата и
время** на консоли.

---

## English summary

Build the engine in WSL1/Linux with devkitPro + scons
(`scripts/wsl/build-godot.sh`, ~1h45m, `lto=none -j2`), package it with
`scripts/wsl/finalizar.sh`, and export the PCK with
`scripts/exportar-pck.ps1`. Keep `module_theora_enabled=True`,
`module_mbedtls_enabled=True`, `module_websocket_enabled=False`,
`builtin_certs=False`. The PCK must exclude `data/` and include `cacert.crt`.
