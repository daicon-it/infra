# vps-zsh-config

Автоматическая настройка zsh-окружения на VPS (Ubuntu/Debian),
воспроизводящая конфигурацию Termux Android.

## Что устанавливается

| Компонент | Описание |
|---|---|
| **zsh** | Основная оболочка |
| **git** | Система контроля версий |
| **fzf** | Нечёткий поиск (Ctrl+R, Ctrl+T) |
| **lsd** | Современная замена `ls` с иконками |
| **zsh-syntax-highlighting** | Подсветка команд в реальном времени |
| **zsh-autosuggestions** | Автодополнение из истории |
| **zsh-z** | Быстрая навигация по директориям |

## Внешний вид

Промпт в стиле Powerline:

```
 ~/projects/myapp
```

- Тёмно-серый сегмент (color 236) с зелёным путём
- Стрелка `\ue0b0` для перехода к следующему сегменту
- Шрифт: **MesloLGS NF** (обязательно для корректного отображения)

## Установка на VPS

### Быстрый старт

```bash
git clone https://github.com/daicon-it/vps-zsh-config.git
cd vps-zsh-config
chmod +x install.sh
./install.sh
```

Затем перезайдите в сессию:

```bash
exec zsh
# или выйдите и войдите снова
```

### Запуск от root (для другого пользователя)

```bash
# Залогинившись как root, запустите от имени целевого пользователя:
sudo -u username bash -c 'cd /tmp && git clone https://github.com/daicon-it/vps-zsh-config.git && cd vps-zsh-config && bash install.sh'
```

### Запуск через sudo

```bash
# Скрипт автоматически определяет SUDO_USER
sudo bash install.sh
```

## Шрифт MesloLGS NF

Для корректного отображения иконок Powerline и lsd необходим шрифт **MesloLGS NF**.
Установите его в вашем терминальном эмуляторе / SSH-клиенте:

| Клиент | Путь к настройке шрифта |
|---|---|
| **iTerm2** (macOS) | Preferences → Profiles → Text → Font |
| **Terminal.app** | Preferences → Profiles → Font |
| **Windows Terminal** | settings.json → `"fontFace"` |
| **PuTTY** | Window → Appearance → Font |
| **Alacritty** | `alacritty.toml` → `[font]` → `family` |
| **Kitty** | `kitty.conf` → `font_family` |

Скачать шрифт: https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf

## Совместимость

| ОС | Версия | Статус |
|---|---|---|
| Ubuntu | 20.04 LTS | Проверено |
| Ubuntu | 22.04 LTS | Проверено |
| Ubuntu | 24.04 LTS | Проверено |
| Debian | 11 (Bullseye) | Проверено |
| Debian | 12 (Bookworm) | Проверено |

## Структура файлов после установки

```
~/.zshrc                                    # Основная конфигурация zsh
~/.zsh-syntax-highlighting/                 # Плагин подсветки синтаксиса
~/.zsh-autosuggestions/                     # Плагин автодополнения
~/.zsh-z/                                   # Плагин быстрой навигации
~/.config/lsd/config.yaml                   # Конфигурация lsd
~/.config/lsd/themes/custom.yaml            # Цветовая тема lsd
```

## Алиасы

```bash
ls    # lsd
ll    # lsd -l
la    # lsd -la
lt    # lsd --tree
```

## Горячие клавиши fzf

| Клавиша | Действие |
|---|---|
| `Ctrl+R` | Поиск по истории команд |
| `Ctrl+T` | Поиск файлов в текущей директории |
| `Alt+C`  | Быстрый переход в поддиректорию |

## Ручная переустановка плагинов

```bash
rm -rf ~/.zsh-syntax-highlighting ~/.zsh-autosuggestions ~/.zsh-z
./install.sh
```

---

> Автор: [daicon-it](https://github.com/daicon-it)
