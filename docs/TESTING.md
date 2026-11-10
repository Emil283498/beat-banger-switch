# Проверка и диагностика вылетов

> English summary at the end.

В сборку встроен «чёрный ящик»: важные шаги записываются в
`dados/depuracao.log` и сбрасываются на карту сразу же. Поэтому даже при
жёстком вылете последняя строка файла показывает, на чём игра упала.

## Что проверять

1. **Запуск** — игра стартует в титульном режиме без экрана ошибки.
2. **Успешный уровень** — пройти уровень до конца. Раньше здесь был вероятный
   вылет из-за финального видео (`climax.webm` + отсутствие ffmpeg). Теперь
   используется `.ogv`, а если его нет — видео отключается.
3. **Game Over** — специально проиграть уровень, подождать ~10 секунд на
   экране, нажать **Retry**, затем **Give up**.
4. **Сохранения** — выйти в меню, полностью закрыть игру, запустить снова;
   прогресс должен остаться.
5. **Моды** — открыть браузер модов: список, обложки, скачивание, запуск.
6. **Онлайн** — если список не грузится, проверьте дату/время на Switch и
   интернет.

## Какие файлы собирать

```
switch/beat-banger/dados/depuracao.log     — главное
switch/beat-banger/beat-banger.log
switch/beat-banger/beat-banger.anterior.log
список switch/beat-banger/dados/ (имя + размер)
список switch/beat-banger/dados/mods/
sdmc:/atmosphere/crash_reports/            — если есть
```

## Как читать `depuracao.log`

- В начале — реальный путь `user://` и список файлов с размерами (видно,
  есть ли `game.sav`).
- `pulso: quadro=... cena=... objetos=... video=...` — **только если в `dados/`
  есть файл `pulso`**. Пульс пишет на карту каждые 2 секунды, поэтому по
  умолчанию выключен (иначе он сам даёт микро-фризы в меню). Для диагностики
  вылета создайте пустой файл `dados/pulso`.
- `save: direto ... erro=0` / `save: copia ... erro=0` — сохранение прошло.
- `gameover: ...` — шаги экрана Game Over.
- `video: ...` — отключилось ли финальное видео.

Диагноз:

| Что видно | Вывод |
|---|---|
| `pulso` идёт до последней строки, потом резко обрывается | краш (SIGSEGV/abort) |
| `pulso` пропал, но игра «висит» | зависание, не краш |
| последняя строка `gameover: ...` | шаг, на котором упало |
| `erro` ≠ 0 в `save:` | не удалось записать (место/ФС/карта только для чтения) |

## A/B-флаги

Создайте в `dados/` **пустой** файл с нужным именем, запустите игру и
повторите проверку. Удалите файл, чтобы вернуть обычное поведение.

| Файл | Что отключает |
|---|---|
| `sem_animacao_go` | анимацию экрана Game Over |
| `sem_audio_go` | звуки экрана Game Over |
| `sem_transicao` | экран загрузки (прямая смена сцены) |
| `sem_save` | запись сохранений |
| `pulso` | наоборот, **включает** пульс раз в 2 секунды |

После каждого опыта `depuracao.log` перезаписывается — скопируйте его перед
следующим запуском.

## Если краш остаётся

1. Проверьте успешное завершение уровня (финальное видео).
2. Проверьте Game Over с флагами по одному.
3. В крайнем случае добавьте в порт обработчик SIGSEGV с backtrace и
   пересоберите движок (см. [BUILD.md](BUILD.md)).

---

## English summary

The build writes `dados/depuracao.log` and flushes every line, so it survives a
hard crash. Test: launch, complete a level, force a Game Over (wait 10 s, Retry,
give up), restart to verify saves, and open the mod browser.

Read the log: an abruptly stopped `pulso` means a crash; a missing `pulso` but a
running game means a hang. The 2 s `pulso` is off by default (it flushes to the
SD card and causes micro-stutters) — create an empty `dados/pulso` file to turn
it on. Empty flag files in `dados/` disable parts for A/B testing:
`sem_animacao_go`, `sem_audio_go`, `sem_transicao`, `sem_save`.
Collect `depuracao.log`, `beat-banger.log` and `atmosphere/crash_reports/`.
