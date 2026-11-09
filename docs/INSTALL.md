# Установка и первый запуск

> English summary at the end.

## Что должно лежать на карте памяти

```
sdmc:/switch/beat-banger/
  beat-banger.nro      — движок Godot + иконка/NACP
  beat-banger.pck      — код игры и ресурсы проекта
  data/                — ресурсы из Steam-версии (~520 МБ)
  dados/               — сохранения, настройки, моды (создаёт игра)
```

Все четыре части должны лежать вместе. `.nro` и `.pck` независимы:
при обновлении только PCK `.nro` менять не нужно.

## Требования

- **Mariko**: Switch V2, Lite или OLED (Erista не тестировался).
- **Atmosphère** + hbmenu.
- **microSD**, желательно **exFAT**. На FAT32 отдельный файл не может быть
  больше 4 ГБ; текущие файлы меньше, но exFAT надёжнее и лучше переносит
  кириллицу.
- Свободное место: около **1.3 ГБ** на `.nro` + `.pck` + `data/`.

## Копирование

1. Скопируйте папку `switch` в **корень** карты microSD.
2. Должно получиться `sdmc:/switch/beat-banger/...`.
3. Не перезаписывайте папку `dados/`, если она уже есть — это ваши сохранения
   и моды.

## Как запускать (важно)

Запускайте в **титульном режиме**, иначе игре не хватит памяти:

1. На главном меню Switch наведите курсор на любую игру.
2. Зажмите **R** и, не отпуская, нажмите **A**.
3. Откроется hbmenu с полной памятью (~3.2 ГБ). Выберите **Beat Banger**.

При запуске из альбома доступно всего ~400 МБ — игра, скорее всего, упадёт.

## Первый запуск

Перед игрой показывается заставка, затем идёт загрузка и сборка кэша шейдеров.
Первый запуск заметно дольше последующих.

Язык по умолчанию — **английский**. Он хранится в `dados/settings.ini`
(`"locale": "en"`). Сменить язык: меню паузы (**+/Start** или **Esc**) →
**Language** → English / Русский.

## Управление

Кнопки как на Switch: нижняя (**B**) — подтверждение, правая (**A**) — отмена.
Стики и крестовина работают как обычно. Вид иконок кнопок (Switch/Xbox/
PlayStation) выбирается в настройках.

## Проверка после установки

- [ ] Игра запускается, есть главное меню и музыка.
- [ ] `dados/` создан, внутри `settings.ini`.
- [ ] Уровень проходится **до конца** без вылета.
- [ ] Game Over → Retry → Give up работают.
- [ ] После перезапуска прогресс сохраняется (`dados/game.sav`).
- [ ] Браузер модов загружает список.
- [ ] Часы Switch выставлены верно (нужно для HTTPS).

Подробная диагностика — в [TESTING.md](TESTING.md).

---

## English summary

Copy the `switch` folder to the SD card root, so you get
`sdmc:/switch/beat-banger/{beat-banger.nro, beat-banger.pck, data/, dados/}`.

Requires a Mariko console (V2/Lite/OLED), Atmosphère + hbmenu, and preferably
an exFAT SD card. Launch in **title mode**: hold **R** while starting any game,
then pick `beat-banger.nro` in hbmenu.

Do **not** overwrite an existing `dados/` folder — it holds saves and mods.
The default language is English (`dados/settings.ini`); change it in the pause
menu → Language.
