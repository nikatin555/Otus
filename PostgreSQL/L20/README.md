# 20.  Резервное копирование и восстановление 

**Домашнее задание**

Бэкапы

**Цель:**

    • применить логический бэкап. Восстановиться из бэкапа. 

Описание/Пошаговая инструкция выполнения домашнего задания:

    1. Создаем ВМ/докер c ПГ.
    2. Создаем БД, схему и в ней таблицу. 
    3. Заполним таблицы автосгенерированными 100 записями. 
    4. Под линукс пользователем Postgres создадим каталог для бэкапов 
    5. Сделаем логический бэкап используя утилиту COPY 
    6. Восстановим в 2 таблицу данные из бэкапа. 
    7. Используя утилиту pg_dump создадим бэкап в кастомном сжатом формате двух таблиц 
    8. Используя утилиту pg_restore восстановим в новую БД только вторую таблицу! 

    # Резервное копирование и восстановление в PostgreSQL

## Пошаговое выполнение задания

### 1. Установка PostgreSQL 17 на AlmaLinux 10

```bash
# Добавляем репозиторий PostgreSQL
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-10-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Устанавливаем PostgreSQL 17
sudo dnf install -y postgresql17-server postgresql17-contrib

# Инициализируем БД
sudo /usr/pgsql-17/bin/postgresql-17-setup initdb

# Запускаем и добавляем в автозагрузку
sudo systemctl enable postgresql-17
sudo systemctl start postgresql-17
```

### 2. Создание пользователя и базы данных

```bash
# Подключемся
sudo -u postgres psql
```
```sql
-- В psql создаем пользователя, базу данных, схему и таблицу
CREATE USER nik WITH PASSWORD 'securepassword';
CREATE DATABASE backup_otus WITH OWNER nik;
GRANT ALL PRIVILEGES ON DATABASE backup_otus TO nik;

-- Подключаемся к новой БД
\c backup_otus nik

-- Создаем схему и таблицу
CREATE SCHEMA otus AUTHORIZATION nik;
CREATE TABLE otus.table_otus (
    id SERIAL PRIMARY KEY,
    data TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Даем права пользователю nik
GRANT ALL PRIVILEGES ON SCHEMA otus TO nik;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA otus TO nik;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA otus TO nik;
```

### 3. Заполнение таблицы 100 записями

```sql
-- В psql под пользователем nik
INSERT INTO otus.table_otus (data)
SELECT md5(random()::text) FROM generate_series(1, 100);
```

### 4. Создание каталога для бэкапов

```bash
# Под пользователем postgres
sudo -i -u postgres
mkdir -p /var/lib/pgsql/17/backups
chmod 700 /var/lib/pgsql/17/backups
sudo chown -R postgres:postgres /var/lib/pgsql/17/backups
```

### 5. Логический бэкап с помощью COPY

```bash
# Под пользователем postgres
psql -d backup_otus -c "COPY otus.table_otus TO '/var/lib/pgsql/17/backups/table_otus_backup.csv' WITH CSV HEADER;"
```
```bash
 psql -d backup_otus -c "COPY otus.table_otus TO '/var/lib/pgsql/17/backups/table_otus_backup.csv' WITH CSV HEADER;"
Пароль пользователя postgres:
COPY 100
```

### 6. Восстановление данных во вторую таблицу

```sql
 psql -U nik -d backup_otus

-- Сначала создаем вторую таблицу
CREATE TABLE otus.table_otus_restored (LIKE otus.table_otus INCLUDING ALL);

-- Восстанавливаем данные из бэкапа
\copy otus.table_otus_restored FROM '/var/lib/pgsql/17/backups/table_otus_backup.csv' WITH CSV HEADER;
```
```sql
 \copy otus.table_otus_restored FROM '/var/lib/pgsql/17/backups/table_otus_backup.csv' WITH CSV HEADER;
COPY 100
```

### 7. Создание бэкапа с pg_dump

```bash
pg_dump -U postgres -d backup_otus -n otus -F c -Z 9 -f /var/lib/pgsql/17/backups/backup_otus_custom.dump
```

### 8. Восстановление только второй таблицы в новую БД

```bash
sudo systemctl restart postgresql-17
# Создаем новую БД
psql -U postgres -c "CREATE DATABASE backup_otus_new WITH OWNER nik;"

# Сначала восстановим только схему
pg_restore -U postgres -d backup_otus_new --schema-only /var/lib/pgsql/17/backups/backup_otus_custom.dump

# Восстанавливаем только вторую таблицу
pg_restore -U postgres -d backup_otus_new -t otus.table_otus_restored /var/lib/pgsql/17/backups/backup_otus_custom.dump

backup_otus_new=> SELECT COUNT(*) FROM otus.table_otus_restored;
 count
-------
   100
(1 строка)
```
## Выводы

1. **COPY vs pg_dump**: Утилита COPY хороша для экспорта/импорта отдельных таблиц в текстовом формате, тогда как pg_dump предоставляет более комплексное решение для резервного копирования с возможностью сжатия и выборочного восстановления.

2. **Гибкость восстановления**: pg_restore позволяет выборочно восстанавливать объекты БД, что очень полезно при работе с большими базами данных.

3. **Права доступа**: Важно правильно настроить права пользователей на БД и каталог для бэкапов.

4. **Форматы бэкапов**: PostgreSQL поддерживает различные форматы резервных копий (plain, custom, directory), каждый из которых имеет свои преимущества в разных сценариях.

5. **Автоматизация**: В production-среде эти операции следует автоматизировать с помощью скриптов и планировщика заданий.