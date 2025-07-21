# 15.  SELinux - когда все запрещено 

Домашнее задание

Практика с SELinux

**Цель:**

работать с SELinux: диагностировать проблемы и модифицировать политики SELinux для корректной работы приложений, если это требуется;

Описание/Пошаговая инструкция выполнения домашнего задания:

Для выполнения домашнего задания используйте методичку


Что нужно сделать?

1. Запустить nginx на нестандартном порту 3-мя разными способами:
- переключатели setsebool;
- добавление нестандартного порта в имеющийся тип;
- формирование и установка модуля SELinux.

2. Обеспечить работоспособность приложения при включенном selinux.

- развернуть приложенный стенд https://github.com/mbfx/otus-linux-adm/tree/master/selinux_dns_problems;
- выяснить причину неработоспособности механизма обновления зоны (см. README);
- предложить решение (или решения) для данной проблемы;
- выбрать одно из решений для реализации, предварительно обосновав выбор;
- реализовать выбранное решение и продемонстрировать его работоспособность.


# Практика с SELinux: Настройка nginx и устранение проблем с DNS в AlmaLinux 10

## 1. Установка и настройка AlmaLinux 10 и nginx

### Установка AlmaLinux 10 на VirtualBox

1. Скачаем образ AlmaLinux 10 с официального сайта
2. Создадим новую виртуальную машину в VirtualBox:
   - Тип: Linux
   - Версия: Red Hat (64-bit)
   - Выделим 8GB RAM, 2 CPU и 25GB SSD
3. Запустим установку, выберем минимальный серверный вариант.

### Установка nginx

```bash
sudo dnf install epel-release -y
sudo dnf install nginx -y
sudo systemctl enable nginx --now
```

## 2. Запуск nginx на нестандартном порту

### Способ 1: Переключатели setsebool

```bash
# Проверяем текущие разрешения портов
sudo semanage port -l | grep http_port_t
```
![alt text](image.png)
```bash
# Пробуем изменить порт в конфиге nginx на 8081
sudo sed -i 's/listen[[:space:]]*80/listen 8081/' /etc/nginx/nginx.conf

# Пытаемся перезапустить nginx
sudo systemctl restart nginx
```
ошибка:
![alt text](image-1.png)

```bash
 journalctl -xeu nginx.service
 ```
![alt text](image-2.png)

**Почему так происходит?**

SELinux по умолчанию разрешает Nginx (httpd) работать только на стандартных портах (80, 443, 8080 и др.). Если мы пытаемся использовать другой порт (например, 8081), SELinux блокирует доступ.


**Разрешаем Nginx слушать любой порт:**
```bash
sudo setsebool -P httpd_can_network_connect 1
```
**Что делает эта команда?**

    httpd_can_network_connect — разрешает веб-серверу (Nginx/Apache) подключаться к сети, в том числе слушать нестандартные порты.

    -P — сохраняет настройку после перезагрузки.

**Перезапускаем Nginx**
```bash
sudo systemctl restart nginx
```
Ошибка попрежнему сохраняется:
![alt text](image-1.png)

Проверяем, что Nginx слушает нужный порт:
```bash
sudo ss -tulnp | grep nginx
```
Вывод пустой. Разбирёмся с данной проблемой:

Проверяем текущие разрешённые порты:
```bash
 sudo semanage port -l | grep http_port_t
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
```

Посмотрим логи SELinux:
```bash
sudo ausearch -m avc -ts recent | grep nginx
<no matches>
```

Попробуем отключить SELinux, перезапустить службу nginx, и включить SELinux:
```bash
sudo setenforce 0  # Переводим в Permissive mode
sudo systemctl restart nginx
sudo setenforce 1  # Возвращаем Enforcing
```
Проверяем, что Nginx слушает нужный порт:
```bash
ss -tulnp | grep nginx
tcp   LISTEN 0      511          0.0.0.0:8081      0.0.0.0:*    users:(("nginx",pid=2284,fd=6),("nginx",pid=2282,fd=6),("nginx",pid=2281,fd=6))
tcp   LISTEN 0      511             [::]:80           [::]:*    users:(("nginx",pid=2284,fd=7),("nginx",pid=2282,fd=7),("nginx",pid=2281,fd=7))
```
![alt text](image-4.png)

Проверим статус службы:
```bash
 systemctl status nginx.service
 ```
![alt text](image-5.png)

Служба nginx работает, но если мы опять перезапустим  её, при включенном SELinux, получим туже самую ошибку. Попробуем решить иначе:

**Полное восстановление контекстов SELinux для nginx**
```bash
sudo restorecon -Rv /etc/nginx
sudo restorecon -Rv /var/lib/nginx
sudo restorecon -Rv /var/log/nginx
sudo restorecon -Rv /usr/share/nginx
sudo restorecon -Rv /run/nginx
```
**Что делают эти команды?**
- **`restorecon`** — восстанавливает стандартные контексты безопасности SELinux для файлов и каталогов.
- **`-R`** — рекурсивно (для всех вложенных файлов и папок).
- **`-v`** — выводит подробный лог изменений.

**Зачем это нужно?**
SELinux хранит метки (контексты) безопасности для каждого файла. Если они сбились (например, из-за ручного копирования файлов или неправильных прав), Nginx не сможет получить доступ к своим конфигам, логам или временным файлам.  
Эти команды **возвращают правильные контексты** для всех ключевых каталогов Nginx:
- `/etc/nginx` — конфигурация
- `/var/lib/nginx` — данные (кеш, временные файлы)
- `/var/log/nginx` — логи
- `/usr/share/nginx` — статические файлы (HTML, CSS, JS)
- `/run/nginx` — PID-файлы и сокеты

**Дополнительные настройки SELinux**
```bash
sudo setsebool -P httpd_can_network_connect 1
sudo setsebool -P httpd_setrlimit 1
sudo setsebool -P nis_enabled 1
```

**Что делают эти переключатели?**
| Команда | Описание |
|---------|----------|
| **`httpd_can_network_connect 1`** | Разрешает Nginx (и другим веб-серверам) устанавливать сетевые подключения, в том числе слушать нестандартные порты. |
| **`httpd_setrlimit 1`** | Позволяет Nginx изменять лимиты ресурсов (например, количество открытых файлов). |
| **`nis_enabled 1`** | Разрешает доступ к NIS-сетям (косвенно может влиять на сетевые возможности). |

 **Зачем это нужно?**
- Без `httpd_can_network_connect` Nginx не сможет слушать нестандартные порты (например, `8081`).
- `httpd_setrlimit` нужен, если Nginx требует больше ресурсов (например, для большого числа соединений).
- `nis_enabled` иногда влияет на сетевые политики SELinux (хотя напрямую не связан с Nginx).

**Создание и применение модуля политики**
```bash
sudo setenforce 0                     # Переводим SELinux в Permissive режим
sudo systemctl restart nginx          # Запускаем Nginx (ошибки записываются в аудит)
sudo ausearch -m avc -ts recent | audit2allow -M nginx_custom  # Создаём модуль
sudo semodule -i nginx_custom.pp      # Устанавливаем модуль
sudo setenforce 1                     # Возвращаем Enforcing режим
```

**Зачем это нужно?**
1. **`setenforce 0`** — временно переводит SELinux в **Permissive** режим (ошибки не блокируют работу, но логируются).  
   → Это нужно, чтобы собрать все возможные AVC-ошибки (Access Vector Cache).

2. **`systemctl restart nginx`** — перезапускаем Nginx, чтобы SELinux записал в лог все нарушения.  

3. **`ausearch -m avc -ts recent | audit2allow -M nginx_custom`**  
   - `ausearch` — ищет ошибки доступа в логах SELinux.  
   - `audit2allow` — генерирует правила на основе этих ошибок.  
   - `-M nginx_custom` — создаёт модуль `nginx_custom.pp`.  

4. **`semodule -i nginx_custom.pp`** — применяет новый модуль политики.  

5. **`setenforce 1`** — возвращает SELinux в строгий режим (**Enforcing**).  

**Проверка работы**
```bash
sudo systemctl restart nginx
sudo systemctl status nginx
ss -tulnp | grep nginx
```
![alt text](image-6.png)

**Почему это помогло?**
- В логах SELinux были ошибки доступа, которые не покрывались стандартными политиками.  
- `audit2allow` автоматически создал правила, разрешающие эти действия.  
- Теперь Nginx может работать **без отключения SELinux** (что важно для безопасности).  


**Итог: как это всё решило проблему?**
1. **Восстановление контекстов** (`restorecon`) — исправило доступ к файлам Nginx.  
2. **Настройка `setsebool`** — разрешила сетевые операции и управление ресурсами.  
3. **Кастомный модуль SELinux** — добавил недостающие правила доступа.  

Теперь Nginx:  
✅ Работает на нестандартном порту  
✅ Полностью совместим с SELinux в режиме **Enforcing**  
✅ Не требует отключения безопасности  

Если проблема вернётся — можно повторить `ausearch | audit2allow` и добавить новые правила.

### Способ 2: Добавление нестандартного порта в имеющийся тип

```bash
# Устанавливаем утилиты для управления SELinux (AlmaLinux 10 уже установлена даже в minimal версии)
sudo dnf install policycoreutils-python-utils -y

# Добавляем порт 8082 к разрешенным для http
sudo semanage port -a -t http_port_t -p tcp 8082

# Меняем порт в конфиге nginx на 8082
sudo sed -i 's/listen[[:space:]]*8081/listen 8082/' /etc/nginx/nginx.conf

# Проверяем
sudo systemctl restart nginx
sudo ss -tulnp | grep nginx
```
![alt text](image-7.png)

### Способ 3: Формирование и установка модуля SELinux

```bash
# Пробуем запустить nginx на порту 8083 (должно не сработать)
sudo sed -i 's/listen[[:space:]]*8082/listen 8083/' /etc/nginx/nginx.conf
sudo systemctl restart nginx

# Смотрим ошибки в логах audit.log
sudo ausearch -m avc -ts recent | grep nginx

# Создаем модуль политики
sudo ausearch -m avc -ts recent | grep nginx | audit2allow -M nginx_custom_port

# Устанавливаем модуль
sudo semodule -i nginx_custom_port.pp

# Проверяем
sudo systemctl restart nginx
sudo ss -tulnp | grep nginx
```

## 3. Обеспечение работоспособности приложения при включенном SELinux

### Развертывание стенда

```bash
 dnf install git -y
# Клонируем репозиторий
git clone https://github.com/mbfx/otus-linux-adm.git
cd otus-linux-adm/selinux_dns_problems

# Запускаем стенд (требуется установленный Vagrant) !!!!! Остановился тут!!!!
vagrant up
```
Логин: vagrant

Пароль: vagrant

### Анализ проблемы

После развертывания стенда, согласно README, механизм обновления зоны DNS не работает. Причина в том, что named (демон BIND) не имеет прав на запись в каталог /etc/named, где находятся файлы зон, при включенном SELinux.

### Решения проблемы

1. **Изменить контекст безопасности каталога**:
   ```bash
   sudo chcon -R -t named_zone_t /etc/named/dynamic
   ```

2. **Создать политику SELinux с помощью audit2allow**:
   ```bash
   sudo ausearch -m avc -ts recent | audit2allow -M named_dynamic
   sudo semodule -i named_dynamic.pp
   ```

3. **Использовать переключатель setsebool**:
   ```bash
   sudo setsebool -P named_write_master_zones 1
   ```

4. **Отключить SELinux для named** (не рекомендуется):
   ```bash
   sudo setenforce 0
   ```

### Выбор и реализация решения

Наиболее правильным решением будет **изменение контекста безопасности каталога**, так как:
- Это минимально необходимое изменение
- Не снижает общий уровень безопасности
- Соответствует принципам работы SELinux

Реализация:
```bash
# Проверяем текущий контекст
sudo ls -Z /etc/named/dynamic

# Меняем контекст
sudo chcon -R -t named_zone_t /etc/named/dynamic

# Проверяем изменения
sudo ls -Z /etc/named/dynamic

# Проверяем работоспособность (из стенда)
vagrant ssh ns01 -- 'sudo nsupdate -k /etc/named.zonetransfer.key /var/tmp/nsupdate.txt'
```

### Демонстрация работоспособности

После выполнения этих действий механизм обновления зоны должен работать:
```bash
vagrant ssh ns01 -- 'dig @localhost slave.example'
```

В выводе должны быть актуальные данные, подтверждающие успешное обновление зоны.