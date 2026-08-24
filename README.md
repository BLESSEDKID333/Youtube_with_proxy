# YouTube for iOS 6 — Native Client

Полноценное нативное приложение YouTube для iOS 6 на Objective-C.

## Архитектура проекта

```
YouTube-iOS6/
├── YouTube.xcodeproj/         # Xcode проект
├── YouTube/
│   ├── Constants.h            # API ключи, URL, цвета, UI константы
│   ├── AppDelegate.h/.m       # Delegate приложения
│   ├── main.m                 # Entry point
│   ├── Info.plist             # Конфигурация приложения
│   ├── Model/
│   │   ├── YTVideo.h/.m      # Модель видео
│   ├── Controllers/
│   │   ├── MainTabBarController   # Таб-бар (5 вкладок)
│   │   ├── TrendingViewController # Главная — Тренды
│   │   ├── CategoriesViewController # Категории
│   │   ├── CategoryVideosViewController # Видео в категории
│   │   ├── SearchViewController  # Поиск
│   │   ├── VideoPlayerViewController # Плеер + инфо + related
│   │   ├── SubscriptionsViewController # Подписки
│   │   └── SettingsViewController # Настройки
│   ├── Views/
│   │   └── VideoCell.h/.m    # Ячейка видео (миниатюра + инфо)
│   └── Networking/
│       ├── YouTubeAPIManager.h/.m  # Сетевой слой (YouTube Data API v3)
│       └── ImageCacheManager.h/.m  # Кэш изображений (память + диск)
└── README.md
```

## Возможности

- **Trending** — трендовые видео с пагинацией и pull-to-refresh
- **Categories** — 10 категорий: Music, Gaming, News, Sports, Education, Comedy и др.
- **Search** — полнотекстовый поиск с историей и автодополнением
- **Video Player** — нативный плеер через MPMoviePlayerController + VPS proxy
- **Video Details** — название, канал, просмотры, дата, описание
- **Related Videos** — похожие видео под плеером
- **Like/Dislike/Share/Save** — кнопки взаимодействия
- **Subscriptions** — заглушка для подписок
- **Settings** — HD, Autoplay, Notifications, Clear Cache
- **Image Caching** — кэш превью в памяти (NSCache) + на диске (MD5-хеш имен файлов)
- **Infinite Scroll** — автозагрузка следующей страницы
- **Network Error Handling** — UIAlertView при ошибках сети/API

## Сборка

### Требования

1. **Xcode 4.6.3** (последний Xcode, поддерживающий iOS 6 SDK)
   - Скачать: https://developer.apple.com/download/more/
   - Или через старый Xcode App Store link
2. **iOS 6 SDK** (входит в Xcode 4.6)
3. **Устройство или Симулятор iOS 6.0+**

### Шаг 1: Получи YouTube API Key

1. Зайди на https://console.developers.google.com
2. Создай новый проект (или выбери существующий)
3. Включи **YouTube Data API v3**: Library → YouTube Data API v3 → Enable
4. Перейди в **Credentials** → **Create Credentials** → **API Key**
5. Скопируй ключ

### Шаг 2: Вставь API Key

Открой файл `YouTube/Constants.h` и замени:

```objc
#define YOUTUBE_API_KEY      @"YOUR_API_KEY_HERE"
```

на:

```objc
#define YOUTUBE_API_KEY      @"AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

### Шаг 3: Открой проект в Xcode

```bash
open YouTube.xcodeproj
```

### Шаг 4: Выбери Target

- Вверху выбери схему **YouTube**
- Выбери **目标** (Target): YouTube
- Выбери **Destination**: iPhone 6 Simulator (или устройство iOS 6)

### Шаг 5: Build & Run

Нажми **Cmd + R** или кнопку **Play**.

## Установка на Устройство

Для установки на реальное устройство:

1. Подключи iPhone/iPad к компьютеру
2. В Xcode выбери устройство в списке Target
3. Если нужен free provisioning: Xcode → Preferences → Accounts → добавь Apple ID
4. Cmd + R — Xcode автоматически создаст provisioning profile

Для iOS 6 устройств:
- iPhone 5 / 5s (последний с iOS 6)
- iPhone 4S (можно откатить через iTunes backup)
- iPad 3 / 4 (с iOS 6)

## Исправление Known Issues

### Проблема: Нет соединения с API на iOS 6
iOS 6 имеет проблемы с TLS 1.2. Решение:
- На реальном устройстве: настройка DNS на Google DNS (8.8.8.8)
- Или используй HTTP вместо HTTPS в Constants.h

### Проблема: YouTube player не загружается
Плеер использует MPMoviePlayerController через VPS proxy. Убедись:
- VPS работает (curl http://VPS_IP/api/extract?videoId=VIDEO_ID)
- Constants.h указывает правильный VPS_IP
- Nginx на VPS настроен (см. VPS/setup.sh)

### Проблема: ARC warnings
Проект использует ARC (`CLANG_ENABLE_OBJC_ARC = YES`). Не используй `retain/release/autorelease` в коде.

## Ключевые файлы для редактирования

| Файл | Назначение |
|------|-----------|
| `Constants.h` | API ключ, URL, цвета, размеры |
| `YTVideo.h/.m` | Модель данных видео |
| `YouTubeAPIManager.h/.m` | Сетевые запросы |
| `VideoPlayerViewController.m` | Плеер и UI видео |
| `VideoCell.m` | Ячейка списка видео |

## Поддерживаемые iPhone

- iPhone 3GS (iOS 6.1.6) — базовая
- iPhone 4 / 4S — полная
- iPhone 5 — полная, оптимальная

---

*Создано для iOS 6 | Objective-C | YouTube Data API v3*
