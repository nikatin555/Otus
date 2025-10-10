Отличная идея! HAProxy - гораздо более надежное решение для балансировки, чем keepalived VIP. Вот как добавить HAProxy в вашу инфраструктуру:

## Архитектура с HAProxy

```
1C Клиенты → HAProxy (новый сервер) → PostgreSQL Patroni (spbpsql1, spbpsql2)
                              ↓
                          etcd кластер (spbetcd1, spbetcd2, spbetcd3)
```

## 1. Создайте новую VM для HAProxy

Добавьте 6-ю VM (например: `sphaproxy1`) с минимальными требованиями:
- 1-2 vCPU, 2GB RAM, 10GB HDD
- AlmaLinux 8/9
- IP: 192.168.10.183 (например)

## 2. Установите и настройте HAProxy

На новой VM `sphaproxy1`:

```bash
# Установите HAProxy
sudo dnf install haproxy -y

# Включите в firewall
sudo firewall-cmd --add-service=http --add-service=https --permanent
sudo firewall-cmd --add-port=5000/tcp --permanent  # для статистики
sudo firewall-cmd --add-port=5432/tcp --permanent  # для PostgreSQL
sudo firewall-cmd --reload
```

## 3. Настройте HAProxy

Создайте конфиг `/etc/haproxy/haproxy.cfg`:

```bash
sudo tee /etc/haproxy/haproxy.cfg << 'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

# Статистика HAProxy (доступна по http://sphaproxy1:5000/stats)
listen stats
    mode http
    bind *:5000
    stats enable
    stats uri /stats
    stats refresh 10s
    stats auth admin:YourSecurePassword123!

# Бэкенд для чтения/записи (только мастер)
backend postgres_master
    mode tcp
    balance first
    option tcp-check
    tcp-check connect port 5432
    tcp-check send PING\r\n
    tcp-check expect string PONG
    server spbpsql1 192.168.10.204:5432 check inter 2s fall 3 rise 2
    server spbpsql2 192.168.10.207:5432 check inter 2s fall 3 rise 2 backup

# Бэкенд для только чтения (все узлы)
backend postgres_replicas
    mode tcp
    balance roundrobin
    option tcp-check
    tcp-check connect port 5432
    tcp-check send PING\r\n
    tcp-check expect string PONG
    server spbpsql1 192.168.10.204:5432 check inter 2s fall 3 rise 2
    server spbpsql2 192.168.10.207:5432 check inter 2s fall 3 rise 2

# Фронтенд для подключений 1С
frontend postgres_frontend
    mode tcp
    bind *:5432
    option tcplog
    
    # Разделение трафика: мастер на порт 5432, реплики на порт 5433
    use_backend postgres_master
    
# Дополнительный порт для только чтения
frontend postgres_readonly
    mode tcp
    bind *:5433
    option tcplog
    use_backend postgres_replicas
EOF
```

## 4. Настройте автоматическое определение мастера

Создайте скрипт для автоматического переключения бэкендов:

```bash
sudo tee /usr/local/bin/pgmaster_check.sh << 'EOF'
#!/bin/bash

MASTER_NODE=$(curl -s http://192.168.10.204:8008 | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('role'))
")

# Обновляем конфиг HAProxy
if [ "$MASTER_NODE" == "leader" ]; then
    # spbpsql1 - мастер
    sed -i 's/server spbpsql1.*/server spbpsql1 192.168.10.204:5432 check inter 2s fall 3 rise 2/' /etc/haproxy/haproxy.cfg
    sed -i 's/server spbpsql2.*/server spbpsql2 192.168.10.207:5432 check inter 2s fall 3 rise 2 backup/' /etc/haproxy/haproxy.cfg
else
    # spbpsql2 - мастер
    sed -i 's/server spbpsql1.*/server spbpsql1 192.168.10.204:5432 check inter 2s fall 3 rise 2 backup/' /etc/haproxy/haproxy.cfg
    sed -i 's/server spbpsql2.*/server spbpsql2 192.168.10.207:5432 check inter 2s fall 3 rise 2/' /etc/haproxy/haproxy.cfg
fi

# Перезагружаем HAProxy
systemctl reload haproxy
EOF

sudo chmod +x /usr/local/bin/pgmaster_check.sh
```

## 5. Настройте cron для автоматической проверки

```bash
sudo tee /etc/cron.d/pgmaster-check << 'EOF'
* * * * * root /usr/local/bin/pgmaster_check.sh
EOF
```

## 6. Запустите HAProxy

```bash
sudo systemctl enable haproxy
sudo systemctl start haproxy
sudo systemctl status haproxy
```

## 7. Настройте 1С для работы с HAProxy

В 1С укажите:
- **Сервер БД**: `sphaproxy1` (или 192.168.10.183)
- **Порт**: `5432` (для чтения/записи) или `5433` (только для чтения)

## 8. Проверьте работу

```bash
# Проверьте подключение через HAProxy
psql -h 192.168.10.183 -U admindbps -d postgres -c "SELECT inet_server_addr();"

# Проверьте статистику
curl -u admin:YourSecurePassword123! http://192.168.10.183:5000/stats
```

## Преимущества этого подхода:

- **Автоматическое failover** - HAProxy сам определяет мастер
- **Балансировка нагрузки** - чтение можно распределять по репликам
- **Мониторинг** - веб-интерфейс статистики
- **Надежность** - не зависит от проблем с VIP
- **Простота** - легче отлаживать и мониторить

Хотите, чтобы я подробнее описал какой-то из шагов?