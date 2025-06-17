
# 10. Bash

# Домашнее задание

Пишем скрипт

**Цель:**

Написать скрипт на языке Bash;

**Описание/Пошаговая инструкция выполнения домашнего задания:**

Написать скрипт для CRON, который раз в час будет формировать письмо и отправлять на заданную почту.

Необходимая информация в письме:

   - Список IP адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта; <br>
   -  Список запрашиваемых URL (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта; <br>
   - Ошибки веб-сервера/приложения c момента последнего запуска; <br>
   - Список всех кодов HTTP ответа с указанием их кол-ва с момента последнего запуска скрипта. <br>
   - Скрипт должен предотвращать одновременный запуск нескольких копий, до его завершения. <br>

В письме должен быть прописан обрабатываемый временной диапазон.

# Подготовка

## Создадим директорию для скрипта и предоставим права:
 ```bash
 mkdir /etc/scripts && chmod +x /etc/scripts
```
## Создам скрипт и дадим права на выполнение:
  ```bash
 sudo nano /etc/scripts/pars_access.sh
```
 ## Дайте права на выполнение:
```bash
sudo chmod 755 /etc/scripts/pars_access.sh
```
## Установка и настройка mailutils для Gmail
```bash
sudo apt update
sudo apt install -y mailutils ssmtp
```
Настройте SSMTP для Gmail:
Добавлю в конфигурацию ssmtp.conf:
```bash
sudo nano /etc/ssmtp/ssmtp.conf
```
```ini
root=nik@gmail.com
mailhub=smtp.gmail.com:587
AuthUser=nik@gmail.com
AuthPass=!@3ffgvfgdd%hghgh&* # использую пароль для приложений
UseSTARTTLS=YES
rewriteDomain=gmail.com
hostname=localhost
FromLineOverride=YES
```

Проверим отправку почты:
```bash
echo "Test message" | mail -s "Test" nik@gmail.com
```

# Скрипт для анализа access.log

Добавляю в файл `/etc/scripts/pars_access.sh` следующее:

```bash
#!/bin/bash

# Блокировка от параллельного запуска
LOCK_FILE="/tmp/pars_access.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "Script is already running. Exiting." >&2
    exit 1
fi

# Конфигурация
LOG_FILE="/var/log/access.log"
LAST_RUN_FILE="/var/log/pars_access_last_run"
EMAIL="nik@gmail.com"
REPORT_FILE="/tmp/access_report.txt"

# Получаем время последнего запуска
current_time=$(date +%s)
if [[ ! -f "$LAST_RUN_FILE" ]]; then
    echo "$current_time" > "$LAST_RUN_FILE"
    exit 0
fi
last_run=$(cat "$LAST_RUN_FILE")

# Форматируем временной диапазон
start_time_str=$(date -d "@$last_run" +"%Y-%m-%d %H:%M:%S")
end_time_str=$(date -d "@$current_time" +"%Y-%m-%d %H:%M:%S")

# Формируем временной фильтр для логов
TZ_OFFSET=$(date +%z)
start_log_str=$(date -d "@$last_run" "+[%d/%b/%Y:%H:%M:%S $TZ_OFFSET]")
end_log_str=$(date -d "@$current_time" "+[%d/%b/%Y:%H:%M:%S $TZ_OFFSET]")

# Генерация отчета
{
    echo "Access Log Report"
    echo "Time range: $start_time_str - $end_time_str"
    echo "=============================================="
    echo
   
    # Топ IP-адресов
    echo "Top 10 IP Addresses:"
    awk -v start="$start_log_str" -v end="$end_log_str" \
        '$4 >= start && $4 <= end {print $1}' "$LOG_FILE" | \
        sort | uniq -c | sort -nr | head -n 10
    echo
   
    # Топ URL
    echo "Top 10 Requested URLs:"
    awk -v start="$start_log_str" -v end="$end_log_str" \
        '$4 >= start && $4 <= end {print $7}' "$LOG_FILE" | \
        sort | uniq -c | sort -nr | head -n 10
    echo
   
    # Ошибки сервера (коды 4xx и 5xx)
    echo "Server Errors (4xx/5xx):"
    awk -v start="$start_log_str" -v end="$end_log_str" \
        '$4 >= start && $4 <= end && $9 >= 400 {print}' "$LOG_FILE"
    echo
   
    # Коды HTTP ответа
    echo "HTTP Status Codes Summary:"
    awk -v start="$start_log_str" -v end="$end_log_str" \
        '$4 >= start && $4 <= end {print $9}' "$LOG_FILE" | \
        sort | uniq -c | sort -nr
} > "$REPORT_FILE"

# Отправка отчета
mail -s "Access Log Report: $start_time_str - $end_time_str" "$EMAIL" < "$REPORT_FILE"

# Обновляем время последнего запуска
echo "$current_time" > "$LAST_RUN_FILE"

# Очистка
rm -f "$REPORT_FILE"
exec 9>&-
```

## Настройка CRON

Установим cron:
```bash
sudo apt install cron -y
```
Убедимся, что служба cron запущена:
```bash
sudo systemctl status cron
```
Настрою автоматический запуск службы при загрузке системы:
```bash
sudo systemctl enable cron
```

Открою crontab:
```bash
sudo crontab -e
```

Добавлю строку для ежечасного выполнения:

```
0 * * * * /etc/scripts/pars_access.sh
```