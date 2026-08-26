# YouTube for iOS 6 — Pure Native Client

Полноценное 100% нативное приложение YouTube для iOS 6 на Objective-C.

---

## 👥 Разработчики

* **Аназерка** — [@anazerka](https://t.me/anazerka)
* **Виктор** — [@nothack4d](https://t.me/nothack4d)
* **Непобедимый** — [@BLESSEDKID87](https://t.me/BLESSEDKID87)

---

## ⚡️ Возможности

- **Нативный вход по QR-коду и Cookie**: Прямой нативный QR-код для мобильного входа YouTube и поле ввода `SAPISID` без задействования VPS.
- **Встроенные корневые TLS-сертификаты**: Автоматическая подгрузка современных CA корневых сертификатов Google для нативных HTTPS запросов в iOS 6.
- **Интерфейс iOS 6 SDK**: Чистый нативный скевоморфный стиль баров, кнопок и таб-бара iOS 6 SDK по умолчанию.
- **Переключатель стиля iOS 7**: Динамический переключатель `iOS 7 Style` в настройках.
- **Тренды (Trending)** — пагинация и pull-to-refresh.
- **Категории (Categories)** — 10 категорий с нативной фильтрацией.
- **Поиск (Search)** — поиск с историей и автодополнением.
- **Shorts** — специальная вкладка коротких видео.
- **Нативный плеер** — просмотр видео через `MPMoviePlayerController`.

---

## 🛠 Сборка через Theos

Проект полностью настроен для сборки через тулчейн **Theos**:

```bash
# Установка Theos (если еще не установлен)
export THEOS=/Users/balls/theos

# Сборка пакета .deb и .ipa
bash build.sh
```

Выходные файлы:
- `.deb` пакет: `./packages/com.youtube.ios6_1.0.4+debug_iphoneos-arm.deb`
- `.ipa` файл: `./YouTube.ipa`

---

## 📲 Установка на iOS 6 устройство

Через USB с помощью `ideviceinstaller`:

```bash
ideviceinstaller -i YouTube.ipa
```

---

*Создано для iOS 6 | Objective-C | YouTube Data API v3*
