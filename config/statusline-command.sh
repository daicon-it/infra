#!/bin/bash
input=$(cat)

# === НАСТРОЙКИ ===
DAILY_BUDGET_MIN=300  # дневной бюджет в минутах (300 = 5 часов)
NARROW_THRESHOLD=50   # <= этого — двухстрочный режим (смартфоны)
# =================

# Ширина statusline: tput cols = ширина терминала, statusline ~45% от неё
if [ -n "$CLAUDE_STATUSLINE_WIDTH" ]; then
    COLS=$CLAUDE_STATUSLINE_WIDTH
else
    TERM_COLS=$(tput cols 2>/dev/null || echo 80)
    RATIO=${CLAUDE_STATUSLINE_RATIO:-45}
    COLS=$(( TERM_COLS * RATIO / 100 ))
    [ "$COLS" -lt 25 ] && COLS=25
fi

# Цвета
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
MAGENTA='\033[35m'
DIM='\033[2m'
RESET='\033[0m'

# === Парсинг JSON ===
HOST_NAME=$(hostname)
MODEL=$(echo "$input" | /usr/bin/jq -r '.model.display_name // "?"')
MODEL_ID=$(echo "$input" | /usr/bin/jq -r '.model.id // ""')
AGENT=$(echo "$input" | /usr/bin/jq -r '.agent.name // ""')
DIR=$(echo "$input" | /usr/bin/jq -r '.workspace.current_dir // ""' | xargs basename 2>/dev/null || echo "?")
PROJECT_DIR=$(echo "$input" | /usr/bin/jq -r '.workspace.project_dir // ""')

BRANCH=""
if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR/.git" ]; then
    BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null)
fi

TOTAL_IN=$(echo "$input" | /usr/bin/jq -r '.context_window.total_input_tokens // 0')
TOTAL_OUT=$(echo "$input" | /usr/bin/jq -r '.context_window.total_output_tokens // 0')
CACHE_READ=$(echo "$input" | /usr/bin/jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
PCT=$(echo "$input" | /usr/bin/jq -r '.context_window.used_percentage // 0' | awk '{printf "%.0f", $1}')
API_DUR_MS=$(echo "$input" | /usr/bin/jq -r '.cost.total_api_duration_ms // 0')

# === Тарифы ===
case "$MODEL_ID" in
    *opus*)  INPUT_PRICE=15.00; OUTPUT_PRICE=75.00; CACHE_READ_PRICE=1.875; TARIFF="in\$15/out\$75" ;;
    *haiku*) INPUT_PRICE=0.80;  OUTPUT_PRICE=4.00;  CACHE_READ_PRICE=0.08;  TARIFF="in\$0.8/out\$4" ;;
    *)       INPUT_PRICE=3.00;  OUTPUT_PRICE=15.00;  CACHE_READ_PRICE=0.30;  TARIFF="in\$3/out\$15" ;;
esac

# === Вычисления ===
SESSION_COST=$(awk -v tin="$TOTAL_IN" -v tout="$TOTAL_OUT" -v cr="$CACHE_READ" \
    -v ip="$INPUT_PRICE" -v op="$OUTPUT_PRICE" -v crp="$CACHE_READ_PRICE" \
    'BEGIN {printf "%.2f", (tin/1000000*ip + tout/1000000*op + cr/1000000*crp)}')
COMPACT_COST=$(echo "$SESSION_COST" | sed -E 's/\.00$//; s/(\.[0-9])0$/\1/')

API_DUR_MIN=$(awk -v ms="$API_DUR_MS" 'BEGIN {printf "%.0f", ms/60000}')
REMAINING_MIN=$((DAILY_BUDGET_MIN - API_DUR_MIN))
[ "$REMAINING_MIN" -lt 0 ] && REMAINING_MIN=0
TIME_REMAINING=$(printf "%d:%02d" $((REMAINING_MIN / 60)) $((REMAINING_MIN % 60)))
TIME_PCT=$(awk -v used="$API_DUR_MIN" -v total="$DAILY_BUDGET_MIN" 'BEGIN {v=used/total*100; if(v>100)v=100; printf "%.0f", v}')

# Цвет времени
if [ "$TIME_PCT" -ge 90 ]; then TIME_COLOR="$RED"
elif [ "$TIME_PCT" -ge 70 ]; then TIME_COLOR="$YELLOW"
else TIME_COLOR="$GREEN"; fi

# Цвет контекста
if [ "$PCT" -ge 65 ]; then CTX_COLOR="$RED"
elif [ "$PCT" -ge 40 ]; then CTX_COLOR="$YELLOW"
else CTX_COLOR="$GREEN"; fi

# === Утилиты ===
make_bar() {
    local pct=$1 width=$2 bar=""
    local filled=$(awk -v p="$pct" -v w="$width" 'BEGIN {printf "%.0f", p/100*w}')
    for ((i=0; i<width; i++)); do
        if [ $i -lt $filled ]; then bar+="█"; else bar+="░"; fi
    done
    echo "$bar"
}

short_model() {
    case "$1" in
        *Opus*)   echo "$1" | sed -E 's/.*Opus ([0-9.]+).*/Op\1/' ;;
        *Sonnet*) echo "$1" | sed -E 's/.*Sonnet ([0-9.]+).*/So\1/' ;;
        *Haiku*)  echo "$1" | sed -E 's/.*Haiku ([0-9.]+).*/Ha\1/' ;;
        *)        echo "$1" ;;
    esac
}

short_host() {
    case "$1" in
        pmx-claude)     echo "pmx" ;;
        postgresql-231) echo "pg231" ;;
        pulscen-232)    echo "pul232" ;;
        kwork-233)      echo "kw233" ;;
        telethon-234)   echo "tg234" ;;
        hiplet-*)       echo "hip${1##*-}" ;;
        *)              echo "$1" ;;
    esac
}

# Заголовок вкладки терминала
printf '\033]0;%s\007' "$HOST_NAME" > /dev/tty 2>/dev/null

# === ПОДГОТОВКА ===
S_HOST=$(short_host "$HOST_NAME")
S_MODEL=$(short_model "$MODEL")

SEP="${DIM}│${RESET}"

# === АДАПТИВНАЯ СБОРКА ===
# Смартфоны (узкий экран): 2 строки — навигация + метрики. Всё видно, ничего не обрезается.
# Планшеты/десктопы (широкий экран): 1 строка с разделителями и барами.

if [ "$COLS" -le "$NARROW_THRESHOLD" ]; then
    # ─── ДВУХСТРОЧНЫЙ: смартфоны ───
    # Строка 1: host │ model │ dir:branch [agent]
    LINE1="${GREEN}${S_HOST}${RESET} ${SEP} ${CYAN}${S_MODEL}${RESET} ${SEP} ${DIR}"
    if [ -n "$BRANCH" ]; then
        LINE1+="${DIM}:${GREEN}${BRANCH}${RESET}"
    fi
    if [ -n "$AGENT" ]; then
        LINE1+=" ${MAGENTA}${AGENT}${RESET}"
    fi

    # Строка 2: $cost time ctx%
    LINE2="${MAGENTA}\$${COMPACT_COST}${RESET} ${SEP} ${TIME_COLOR}${TIME_REMAINING}${RESET} ${SEP} ${CTX_COLOR}${PCT}%${RESET}"

    printf '%b\n' "$LINE1"
    printf '%b' "$LINE2"

else
    # ─── ОДНОСТРОЧНЫЙ: планшеты и десктопы ───
    LINE="${GREEN}${S_HOST}${RESET} ${SEP} ${CYAN}${S_MODEL}${RESET} ${SEP} ${DIR}"
    USED=$(( ${#S_HOST} + 3 + ${#S_MODEL} + 3 + ${#DIR} ))
    if [ -n "$BRANCH" ]; then
        LINE+="${DIM}:${GREEN}${BRANCH}${RESET}"
        USED=$((USED + 1 + ${#BRANCH}))
    fi

    # Agent
    if [ -n "$AGENT" ]; then
        LINE+=" ${SEP} ${MAGENTA}${AGENT}${RESET}"
        USED=$((USED + 3 + ${#AGENT}))
    fi

    # Cost
    LINE+=" ${SEP} ${MAGENTA}\$${SESSION_COST}${RESET}"
    USED=$((USED + 3 + 1 + ${#SESSION_COST}))

    # Time — с баром если хватает
    REMAINING=$((COLS - USED))
    if [ "$REMAINING" -gt 30 ]; then
        TIME_BAR=$(make_bar "$TIME_PCT" 5)
        LINE+=" ${SEP} ${TIME_COLOR}${TIME_BAR} ${TIME_REMAINING}${RESET}"
        USED=$((USED + 3 + 6 + ${#TIME_REMAINING}))
    else
        LINE+=" ${SEP} ${TIME_COLOR}${TIME_REMAINING}${RESET}"
        USED=$((USED + 3 + ${#TIME_REMAINING}))
    fi

    # Context — с баром если хватает
    REMAINING=$((COLS - USED))
    if [ "$REMAINING" -gt 20 ]; then
        CTX_BAR=$(make_bar "$PCT" 5)
        LINE+=" ${SEP} ${CTX_COLOR}${CTX_BAR} ${PCT}%${RESET}"
    else
        LINE+=" ${SEP} ${CTX_COLOR}${PCT}%${RESET}"
    fi

    # Tariff — если ещё есть место
    USED_NOW=$(printf '%b' "$LINE" | sed 's/\x1b\[[0-9;]*m//g' | wc -m)
    TARIFF_LEN=$(( ${#TARIFF} + 3 ))
    if [ $((USED_NOW + TARIFF_LEN)) -le "$COLS" ]; then
        LINE+=" ${DIM}(${TARIFF})${RESET}"
    fi

    printf '%b' "$LINE"
fi
