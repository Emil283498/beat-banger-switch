# Как обновлять сборку

> English summary at the end.

Сборка состоит из трёх независимых слоёв, и обновляются они по-разному.

| Слой | Что это | Как обновляется |
|---|---|---|
| `data/` | ресурсы Steam-версии (`.ogv`, `.ogg`, картинки) | копированием |
| `beat-banger.pck` | код игры, сцены, ресурсы проекта | переэкспортом PCK |
| `beat-banger.nro` | движок Godot + иконка/NACP | только при смене движка/порта |

> [!CAUTION]
> Папка `dados/` — это сохранения (`game.sav`), настройки и моды.
> При любом обновлении её **не удаляйте и не перезаписывайте**.

---

## Сценарий A. Обновились только ресурсы (`data/`)

1. Скопируйте новую папку `data/` из Steam-версии поверх старой.
2. Скиньте `data/` на карту поверх.
3. `dados/` не трогайте.

Если новый код ссылается на новые файлы — нужен сценарий B.

## Сценарий B. Обновилась сама игра (новые уровни/механики/сцены)

1. Декомпилируйте новую версию игры в **новую** папку (GDRE Tools).
2. Перенесите порт-правки — список в [PORTING-NOTES.md](PORTING-NOTES.md).
3. Переимпортируйте и экспортируйте PCK:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\exportar-pck.ps1 `
       -Projeto .\game -Destino .\out\beat-banger.pck `
       -Godot "C:\Tools\Godot472\Godot_v4.7.2-stable_win64_console.exe"
   ```
4. Скрипт сам проверит, что в PCK нет `data/` и что внутри есть `cacert.crt`
   (если он есть в проекте). Должно быть `OK` в конце.
5. Скопируйте `beat-banger.pck` на карту. `dados/` не трогайте.
   `.nro` менять не нужно.

## Сценарий C. Обновился движок Godot или сам порт

```bash
# WSL1
export GODOT_SRC=$HOME/godot-switch-nro-trabalho/godot
bash scripts/wsl/build-godot.sh
bash scripts/wsl/finalizar.sh
bash scripts/wsl/verificar-nro.sh ./beat-banger.nro
```

Версия NACP задаётся переменной `VERSION` (по умолчанию `1.0.0`):

```bash
VERSION=1.1.0 bash scripts/wsl/finalizar.sh
```

Подробности — в [BUILD.md](BUILD.md).

## Сценарий D. Обновились видео модов (`.webm`)

Движок понимает только `.ogv` (Theora). Сконвертируйте видео на ПК:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\converter-videos-mods.ps1 `
    -Pasta "E:\switch\beat-banger\dados\mods"
```

Скрипт создаёт рядом с каждым `X.webm` файл `X.ogv` и правит ссылки в
настройках этого мода.

Флаги:

- `-Forcar` — переконвертировать, даже если `.ogv` свежее;
- `-ApagarWebm` — удалить `.webm` после успешной конвертации;
- `-SemReescreverConfig` — только конвертировать, конфиги не трогать.

## Про сохранения

```
dados/game.sav        основной сейв
dados/game.sav.bak1   предыдущее сохранение
dados/game.sav.bak2   более старое
dados/game.sav.bak3   самое старое
```

Запись идёт напрямую (без переименования файла — так надёжнее на FAT/exFAT),
а копии делаются копированием. Если основной сейв не читается, игра пробует
восстановить его из `.bak1..3`. Если не читается ни один — игра перестаёт
сохранять, чтобы не испортить данные.

Проверка записи — в `dados/depuracao.log`: строки
`save: direto ... erro=0` и `save: copia ... erro=0`.

Чтобы перенести прогресс на другую карту — скопируйте **всю** папку `dados/`.

---

## English summary

Three independent layers: `data/` (copy), `beat-banger.pck` (re-export with
`scripts/exportar-pck.ps1`), `beat-banger.nro` (rebuild engine only when the
engine/port changes). Never delete or overwrite `dados/` — it holds saves
(`game.sav` + `.bak1..3`), settings and mods. To move progress, copy the whole
`dados/` folder.
