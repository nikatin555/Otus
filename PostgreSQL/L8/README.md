# 8. Журналы 

## Домашнее задание

Работа с журналами

**Цель:**

    уметь работать с журналами и контрольными точками
    уметь настраивать параметры журналов


**Описание/Пошаговая инструкция выполнения домашнего задания:**

    1. Настройте выполнение контрольной точки раз в 30 секунд.
    2. 10 минут c помощью утилиты pgbench подавайте нагрузку.
    3. Измерьте, какой объем журнальных файлов был сгенерирован за это время. Оцените, какой объем приходится в среднем на одну контрольную точку.
    4. Проверьте данные статистики: все ли контрольные точки выполнялись точно по расписанию. Почему так произошло?
    5. Сравните tps в синхронном/асинхронном режиме утилитой pgbench. Объясните полученный результат.
    6. Создайте новый кластер с включенной контрольной суммой страниц. Создайте таблицу. Вставьте несколько значений. Выключите кластер. Измените пару байт в таблице. Включите кластер и сделайте выборку из таблицы. Что и почему произошло? как проигнорировать ошибку и продолжить работу?

### Пошаговая инструкция для Ubuntu 24.04 и PostgreSQL 17

#### 1. Настройка выполнения контрольной точки раз в 30 секунд

1. Установите PostgreSQL 17
```bash
sudo apt install -y postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
sudo apt install curl ca-certificates
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
. /etc/os-release
sudo sh -c "echo 'deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $VERSION_CODENAME-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
sudo apt update
sudo apt -y install postgresql
```

2. Откроем конфигурационный файл `postgresql.conf`:
   ```bash
   sudo nano /etc/postgresql/17/main/postgresql.conf
   ```

3. Изменим параметры, связанные с контрольными точками:
   ```ini
   checkpoint_timeout = 30s          # Частота выполнения контрольных точек
   checkpoint_completion_target = 0.9 # Доля времени между контрольными точками для записи изменений
   ```

4. Перезапустим PostgreSQL для применения изменений:
   ```bash
   sudo systemctl restart postgresql@17-main
   ```
#### 2. Нагрузка с помощью `pgbench` в течение 10 минут

1. Создаём тестовую БД:
   ```bash
   sudo -u postgres createdb pgbench_test
   ```

2. Инициализируем `pgbench_test`:
   ```bash
   sudo -u postgres pgbench -i pgbench_test
   ```

3. Запустим нагрузку на 10 минут:
   ```bash
   sudo -u postgres pgbench -T 600 -c 10 -j 2 pgbench_test
   ```

#### 3. Измерение объёма сгенерированных журнальных файлов (WAL)

1. Определим текущий WAL-файл:
   ```bash
   sudo -u postgres psql -c "SELECT pg_current_wal_lsn();"
   ```

2. После завершения нагрузки проверим новый WAL:
   ```bash
   sudo -u postgres psql -c "SELECT pg_current_wal_lsn();"
   ```

3. Рассчитаем разницу в байтах:
   ```bash
   sudo -u postgres psql -c "SELECT pg_wal_lsn_diff('LSN_конечный', 'LSN_начальный') / 1024 / 1024 AS wal_size_mb;"
   ```

4. Оценим средний объём на одну контрольную точку:
   - За 10 минут (600 сек) при `checkpoint_timeout = 30s` будет выполнено `600 / 30 = 20` контрольных точек.
   - Средний объём: `Общий_объём_WAL / 20`.

#### 4. Проверка статистики контрольных точек

1. Посмотрим статистику в логах PostgreSQL: ????
   ```bash
   sudo cat /var/log/postgresql/postgresql-17-main.log | grep "checkpoint"
   ```

2. Или запросим из БД:
   ```bash
   sudo -u postgres psql -c "SELECT * FROM pg_stat_bgwriter;"
   ```

3. Если контрольные точки выполнялись не точно по расписанию, возможные причины:
   - Нагрузка на диск.
   - Достигнут `max_wal_size`, и PostgreSQL инициировал раннюю контрольную точку.

#### 5. Сравнение TPS в синхронном и асинхронном режиме

1. **Синхронный режим** (по умолчанию):
   ```bash
   sudo -u postgres psql -c "ALTER SYSTEM SET synchronous_commit TO on;"
   sudo systemctl restart postgresql@17-main
   sudo -u postgres pgbench -T 60 -c 10 pgbench_test
   ```
2. **Асинхронный режим** (более высокая производительность, но риск потери данных):
   ```bash
   sudo -u postgres psql -c "ALTER SYSTEM SET synchronous_commit TO off;"
   sudo systemctl restart postgresql@17-main
   sudo -u postgres pgbench -T 60 -c 10 pgbench_test
   ```
3. **Результат**: В асинхронном режиме TPS будет выше, так как транзакции не ждут подтверждения записи на диск.

#### 6. Проверка контрольных сумм страниц

1. Создадим новый кластер с включёнными контрольными суммами:
   ```bash
   sudo pg_createcluster 17 test_checksum -- --data-checksums
   sudo pg_ctlcluster 17 test_checksum start
   ```

2. Создадим таблицу и вставим данные:
   ```bash
   sudo -u postgres psql -p $(sudo pg_lsclusters | grep test_checksum | awk '{print $3}') -c "CREATE TABLE test (id int); INSERT INTO test VALUES (1), (2), (3);"
   ```

3. Остановим кластер:
   ```bash
   sudo pg_ctlcluster 17 test_checksum stop
   ```

4. Найдём файл таблицы и изменим:
   ```bash
   sudo find /var/lib/postgresql/17/test_checksum -name "*.dat" | xargs sudo ls -la
   sudo dd if=/dev/zero of=/path/to/table_file bs=1 count=1 seek=100 conv=notrunc
   ```

5. Запустим кластер и попробуем прочитать данные:
   ```bash
   sudo pg_ctlcluster 17 test_checksum start
   sudo -u postgres psql -p $(sudo pg_lsclusters | grep test_checksum | awk '{print $3}') -c "SELECT * FROM test;"
   ```

6. **Что произойдёт?**  
   PostgreSQL обнаружит повреждение данных из-за несовпадения контрольной суммы и выдаст ошибку.

7. **Как проигнорировать ошибку?**  
   Можно временно отключить проверку (только для анализа!):
   ```bash
   sudo -u postgres psql -p $(sudo pg_lsclusters | grep test_checksum | awk '{print $3}') -c "SET ignore_checksum_failure TO on; SELECT * FROM test;"
   ```

### Выводы
- Контрольные точки влияют на генерацию WAL.
- Асинхронный режим повышает TPS, но снижает надёжность.
- Контрольные суммы страниц защищают от повреждения данных.