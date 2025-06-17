# 12. Управление процессами

## Домашнее задание

Работа с процессами

**Цель:**

Работать с процессами;

Задание:

   1. написать свою реализацию ps ax используя анализ /proc; <br>
    - Результат ДЗ - рабочий скрипт который можно запустить.

# Реализация `ps ax` через анализ /proc

Cкрипт на Bash, который имитирует поведение `ps ax`, анализируя содержимое директории `/proc`:

```bash
#!/bin/bash

# Заголовок вывода
printf "  PID TTY      STAT   TIME COMMAND\n"

# Перебираем все числовые директории в /proc (каждая соответствует процессу)
for pid in $(ls -d /proc/[0-9]*/ | awk -F/ '{print $3}' | sort -n); do
    # Проверяем, существует ли директория процесса (процесс мог завершиться)
    if [ -d "/proc/$pid" ]; then
        # Читаем информацию о процессе
        
        # TTY (терминал)
        tty=$(readlink /proc/$pid/fd/0 2>/dev/null | sed 's/\/dev\///')
        if [ -z "$tty" ]; then
            tty="?"
        elif [[ "$tty" == "pts"* ]]; then
            tty=${tty#pts/}
            tty="pts/$tty"
        fi
        
        # Статус процесса
        stat=$(cat /proc/$pid/status 2>/dev/null | grep "State:" | awk '{print $2}')
        if [ -z "$stat" ]; then
            stat="?"
        fi
        
        # Время процессора (user + sys)
        utime=$(cat /proc/$pid/stat 2>/dev/null | awk '{print $14}')
        stime=$(cat /proc/$pid/stat 2>/dev/null | awk '{print $15}')
        if [ -z "$utime" ] || [ -z "$stime" ]; then
            cputime="0:00"
        else
            total_ticks=$((utime + stime))
            total_sec=$((total_ticks / $(getconf CLK_TCK)))
            min=$((total_sec / 60))
            sec=$((total_sec % 60))
            cputime=$(printf "%d:%02d" $min $sec)
        fi
        
        # Командная строка
        cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
        if [ -z "$cmdline" ]; then
            # Если командной строки нет, берем имя из stat
            cmdline=$(cat /proc/$pid/stat 2>/dev/null | awk '{print $2}' | tr -d '()')
            cmdline="["$cmdline"]"
        fi
        
        # Выводим информацию о процессе
        printf "%5d %-8s %-6s %6s %s\n" "$pid" "$tty" "$stat" "$cputime" "$cmdline"
    fi
done
```
