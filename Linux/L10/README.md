
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

## Создадим директорию для скрипта:
 ```bash
 mkdir /etc/scripts
```
## Создам скрипт и дадим права на выполнение:
  ```bash
 sudo nano /etc/scripts/pars_access.sh && sudo chmod +x /etc/scripts/pars_access.sh
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

# Конфигурация
LOG_FILE="/var/log/access.log"
REPORT_FILE="/tmp/access_log_report.txt"
TMP_FILE="/tmp/access_log_tmp.txt"
LAST_RUN_FILE="/tmp/access_log_last_run.txt"
LOCKFILE="/tmp/access_log_pars_access.lock"
SCRIPT_LOG="/var/log/access_log_pars_access.log"
EMAIL_TO="nik@gmail.com"
EMAIL_SUBJECT="Access Log Report"

# Функция для логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$SCRIPT_LOG"
}

# Проверка и создание lock файла
if [ -f "$LOCKFILE" ]; then
    log "Script is already running. Exiting."
    exit 1
fi

touch "$LOCKFILE"
trap 'rm -f "$LOCKFILE"; log "Script terminated"; exit' INT TERM EXIT

log "Starting script execution"

# Получаем текущую дату и время
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# Получаем текущую позицию в лог-файле
CURRENT_SIZE=$(stat -c %s "$LOG_FILE" 2>/dev/null)

if [ -z "$CURRENT_SIZE" ]; then
    log "Error: Log file $LOG_FILE not found"
    exit 1
fi

# Проверяем предыдущий запуск
if [ -f "$LAST_RUN_FILE" ]; then
    LAST_SIZE=$(cat "$LAST_RUN_FILE")
    if [ "$CURRENT_SIZE" -lt "$LAST_SIZE" ]; then
        log "Log file was rotated or truncated. Analyzing from beginning."
        TAIL_POS=0
    else
        TAIL_POS=$LAST_SIZE
    fi
else
    log "First run. Analyzing entire log file."
    TAIL_POS=0
fi

# Сохраняем текущую позицию
echo "$CURRENT_SIZE" > "$LAST_RUN_FILE"

# Создаем временный файл с новыми записями
dd if="$LOG_FILE" bs=1 skip="$TAIL_POS" 2>/dev/null > "$TMP_FILE"

# Получаем временной диапазон из лога
FIRST_LINE_TIME=$(head -n 1 "$TMP_FILE" | awk -F'[][]' '{print $2}' 2>/dev/null || echo "unknown")
LAST_LINE_TIME=$(tail -n 1 "$TMP_FILE" | awk -F'[][]' '{print $2}' 2>/dev/null || echo "unknown")

# Генерируем отчет
echo "Access Log Report - $(date)" > "$REPORT_FILE"
echo "Time range in log: $FIRST_LINE_TIME - $LAST_LINE_TIME" >> "$REPORT_FILE"
echo "Report generated at: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT_FILE"
echo "Analyzed entries: $(wc -l < "$TMP_FILE")" >> "$REPORT_FILE"
echo "======================================" >> "$REPORT_FILE"

# 1. Топ IP адресов
echo -e "\nTop IP Addresses:" >> "$REPORT_FILE"
awk '{print $1}' "$TMP_FILE" | sort | uniq -c | sort -nr | head -n 10 >> "$REPORT_FILE"

# 2. Топ запрашиваемых URL
echo -e "\nTop Requested URLs:" >> "$REPORT_FILE"
awk '{print $7}' "$TMP_FILE" | sort | uniq -c | sort -nr | head -n 10 >> "$REPORT_FILE"

# 3. Ошибки веб-сервера/приложения
echo -e "\nServer/Application Errors:" >> "$REPORT_FILE"
grep -E ' (4[0-9]{2}|5[0-9]{2}) ' "$TMP_FILE" >> "$REPORT_FILE"

# 4. Список всех кодов HTTP ответа
echo -e "\nHTTP Status Codes:" >> "$REPORT_FILE"
awk '{print $9}' "$TMP_FILE" | sort | uniq -c | sort -nr >> "$REPORT_FILE"

# Отправка отчета по email
if [ -f "$REPORT_FILE" ]; then
    mailx -s "$EMAIL_SUBJECT ($FIRST_LINE_TIME - $LAST_LINE_TIME)" "$EMAIL_TO" < "$REPORT_FILE"
    if [ $? -eq 0 ]; then
        log "Report sent successfully to $EMAIL_TO"
    else
        log "Failed to send email to $EMAIL_TO"
    fi
else
    log "Error: Report file not found"
fi

# Очистка
rm -f "$TMP_FILE" "$LOCKFILE"

END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
log "Script completed successfully. Execution time: $START_TIME - $END_TIME"
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