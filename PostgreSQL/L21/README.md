# 21.  Виды и устройство репликации в PostgreSQL. Практика применения 

## Домашнее задание

Репликация

Цель:

    реализовать свой миникластер на 3 ВМ.


Описание/Пошаговая инструкция выполнения домашнего задания:

    1. На 1 ВМ создаем таблицы test для записи, test2 для запросов на чтение.
    2. Создаем публикацию таблицы test и подписываемся на публикацию таблицы test2 с ВМ №2.
    3. На 2 ВМ создаем таблицы test2 для записи, test для запросов на чтение.
    4. Создаем публикацию таблицы test2 и подписываемся на публикацию таблицы test1 с ВМ №1.
    5. 3 ВМ использовать как реплику для чтения и бэкапов (подписаться на таблицы из ВМ №1 и №2 ).


ДЗ сдается в виде миниотчета на гитхабе с описанием шагов и с какими проблемами столкнулись.


* реализовать горячее реплицирование для высокой доступности на 4ВМ. Источником должна выступать ВМ №3. Написать с какими проблемами столкнулись.


# Реализация мини-кластера PostgreSQL 17 на 4 VM с репликацией

## 1. Настройка VM №1 (основной сервер)

```bash
# Установка PostgreSQL 17
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-10-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo dnf install -y postgresql17-server

# Инициализация кластера
sudo /usr/pgsql-17/bin/postgresql-17-setup initdb
sudo systemctl enable postgresql-17
sudo systemctl start postgresql-17

# Настройка кластера
sudo -u postgres psql -c "CREATE USER nik WITH SUPERUSER PASSWORD 'password';"
sudo -u postgres psql -c "CREATE DATABASE otus_db OWNER nik;"
sudo -u postgres psql -d otus_db -c "CREATE SCHEMA otus_sch AUTHORIZATION nik;"

# Создание таблиц
sudo -u postgres psql -d otus_db -c "
CREATE TABLE otus_sch.test (id serial PRIMARY KEY, data text);
CREATE TABLE otus_sch.test2 (id serial PRIMARY KEY, data text);
"

# Настройка pg_hba.conf для репликации
echo "host replication all 192.168.0.0/16 md5" | sudo tee -a /var/lib/pgsql/17/data/pg_hba.conf
echo "host all all 192.168.0.0/16 md5" | sudo tee -a /var/lib/pgsql/17/data/pg_hba.conf

# Настройка postgresql.conf
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/17/data/postgresql.conf
echo "wal_level = logical" | sudo tee -a /var/lib/pgsql/17/data/postgresql.conf
echo "max_wal_senders = 10" | sudo tee -a /var/lib/pgsql/17/data/postgresql.conf
echo "max_replication_slots = 10" | sudo tee -a /var/lib/pgsql/17/data/postgresql.conf

# Перезапуск PostgreSQL
sudo systemctl restart postgresql-17

# Создание публикации для таблицы test
sudo -u postgres psql -d otus_db -c "CREATE PUBLICATION pub_test FOR TABLE otus_sch.test;"
```

## 2. Настройка VM №2 (вторичный сервер)

```bash
# Установка PostgreSQL 17 (аналогично VM №1)
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-10-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo dnf install -y postgresql17-server

# Инициализация кластера
sudo /usr/pgsql-17/bin/postgresql-17-setup initdb
sudo systemctl enable postgresql-17
sudo systemctl start postgresql-17

# Настройка кластера
sudo -u postgres psql -c "CREATE USER nik WITH SUPERUSER PASSWORD 'password';"
sudo -u postgres psql -c "CREATE DATABASE otus_db OWNER nik;"
sudo -u postgres psql -d otus_db -c "CREATE SCHEMA otus_sch AUTHORIZATION nik;"

# Создание таблиц
sudo -u postgres psql -d otus_db -c "
CREATE TABLE otus_sch.test (id serial PRIMARY KEY, data text);
CREATE TABLE otus_sch.test2 (id serial PRIMARY KEY, data text);
"

# Настройка подключения (аналогично VM №1)
echo "host replication all 192.168.0.0/16 md5" | sudo tee -a /var/lib/pgsql/17/data/pg_hba.conf
echo "host all all 192.168.0.0/16 md5" | sudo tee -a /var/lib/pgsql/17/data/pg_hba.conf
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/17/data/postgresql.conf
echo "wal_level = logical" | sudo tee -a /var/lib/pgsql/17/data/postgresql.conf
echo "max_wal_senders = 10" | sudo tee -a /var/lib/pgsql/17/data/postgresql.conf
echo "max_replication_slots = 10" | sudo tee -a /var/lib/pgsql/17/data/postgresql.conf

sudo systemctl restart postgresql-17

# Создание публикации для таблицы test2
sudo -u postgres psql -d otus_db -c "CREATE PUBLICATION pub_test2 FOR TABLE otus_sch.test2;"

# Подписка на публикацию test с VM №1
sudo -u postgres psql -d otus_db -c "
CREATE SUBSCRIPTION sub_test 
CONNECTION 'host=vm1 user=nik password=password dbname=otus_db' 
PUBLICATION pub_test WITH (copy_data = true);
"
```

## 3. Завершение настройки репликации между VM №1 и VM №2

На VM №1 добавляем подписку на публикацию с VM №2:

```bash
sudo -u postgres psql -d otus_db -c "
CREATE SUBSCRIPTION sub_test2 
CONNECTION 'host=vm2 user=nik password=password dbname=otus_db' 
PUBLICATION pub_test2 WITH (copy_data = true);
"
```

## 4. Настройка VM №3 (реплика для чтения и бэкапов)

```bash
# Установка PostgreSQL 17 (аналогично предыдущим)
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-10-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo dnf install -y postgresql17-server

# Инициализация кластера
sudo /usr/pgsql-17/bin/postgresql-17-setup initdb
sudo systemctl enable postgresql-17
sudo systemctl start postgresql-17

# Настройка кластера
sudo -u postgres psql -c "CREATE USER nik WITH SUPERUSER PASSWORD 'password';"
sudo -u postgres psql -c "CREATE DATABASE otus_db OWNER nik;"
sudo -u postgres psql -d otus_db -c "CREATE SCHEMA otus_sch AUTHORIZATION nik;"

# Создание таблиц (структура должна соответствовать)
sudo -u postgres psql -d otus_db -c "
CREATE TABLE otus_sch.test (id serial PRIMARY KEY, data text);
CREATE TABLE otus_sch.test2 (id serial PRIMARY KEY, data text);
"

# Настройка подключения
echo "host replication all 192.168.0.0/16 md5" | sudo tee -a /var/lib/pgsql/17/data/pg_hba.conf
echo "host all all 192.168.0.0/16 md5" | sudo tee -a /var/lib/pgsql/17/data/pg_hba.conf
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/17/data/postgresql.conf
echo "wal_level = logical" | sudo tee -a /var/lib/pgsql/17/data/postgresql.conf
echo "max_wal_senders = 10" | sudo tee -a /var/lib/pgsql/17/data/postgresql.conf
echo "max_replication_slots = 10" | sudo tee -a /var/lib/pgsql/17/data/postgresql.conf
echo "hot_standby = on" | sudo tee -a /var/lib/pgsql/17/data/postgresql.conf

sudo systemctl restart postgresql-17

# Подписка на публикации с VM №1 и VM №2
sudo -u postgres psql -d otus_db -c "
CREATE SUBSCRIPTION sub_test_vm1 
CONNECTION 'host=vm1 user=nik password=password dbname=otus_db' 
PUBLICATION pub_test WITH (copy_data = true, enabled = true);

CREATE SUBSCRIPTION sub_test2_vm2 
CONNECTION 'host=vm2 user=nik password=password dbname=otus_db' 
PUBLICATION pub_test2 WITH (copy_data = true, enabled = true);
"
```

## 6.* Настройка VM №4 (горячая репликация с VM №3)

```bash
# Установка PostgreSQL 17 (аналогично предыдущим)
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-10-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo dnf install -y postgresql17-server

# Остановка PostgreSQL (если запущен)
sudo systemctl stop postgresql-17

# Удаление каталога данных
sudo rm -rf /var/lib/pgsql/17/data

# Создание физической реплики с VM №3
sudo -u postgres pg_basebackup -h vm3 -U nik -D /var/lib/pgsql/17/data -P -R

# Настройка recovery.conf (PostgreSQL 17 использует standby.signal)
echo "primary_conninfo = 'host=vm3 user=nik password=password'" | sudo tee -a /var/lib/pgsql/17/data/postgresql.conf
sudo touch /var/lib/pgsql/17/data/standby.signal

# Запуск PostgreSQL
sudo systemctl start postgresql-17
```

**Проблемы, с которыми можно столкнуться:**
1. Расхождение в версиях PostgreSQL на разных VM
2. Проблемы с сетевым доступом между VM
3. Ошибки аутентификации (неправильные настройки pg_hba.conf)
4. Конфликты при логической репликации (например, при вставке одинаковых PK)
5. Задержки репликации при высокой нагрузке

## 7. Ответ на вопрос о необходимости создания кластера на всех VM

Нет, не обязательно создавать идентичный кластер на всех VM. Для физической репликации (VM №4) данные копируются полностью с мастера. Однако для логической репликации (VM №1-3) необходимо:
- Иметь одинаковую структуру таблиц (имена, типы данных)
- Иметь права доступа для пользователя репликации
- Но база данных и схема должны существовать перед созданием подписки

## 8. Выводы

1. PostgreSQL предоставляет гибкие механизмы репликации: логическую (на уровне таблиц) и физическую (на уровне всего кластера).
2. Логическая репликация позволяет выбирать конкретные таблицы для репликации и настраивать двустороннюю репликацию.
3. Физическая репликация обеспечивает полную копию кластера и подходит для горячего резервирования.
4. Комбинирование подходов позволяет создать отказоустойчивую систему с разделением нагрузки.
5. Основные сложности при настройке связаны с сетевым доступом, аутентификацией и согласованностью данных.

Реализованная архитектура:
- VM1 и VM2: двусторонняя логическая репликация отдельных таблиц
- VM3: подписчик на обе публикации (для чтения и бэкапов)
- VM4: физическая реплика VM3 для высокой доступности

-----------------------------------------------------------------------


# Настройка 4 VM с PostgreSQL 17 и репликацией с помощью Ansible

Ниже представлен набор Ansible ролей и плейбуков для настройки кластера PostgreSQL 17 с репликацией на 4 виртуальных машинах.

## Создание структуры каталогов и файлов

```bash
# Создаем структуру каталогов для всех ролей
mkdir -p postgresql-cluster/{inventory/group_vars,roles/{common,postgresql,replication,standby}/tasks}
#Для надежности повторим для подкаталогов
mkdir -p roles/{common,postgresql,replication,standby}/{handlers,templates,files,vars}

# Переход в директорию проекта
cd postgresql-cluster

# Создание основных файлов
touch site.yml
touch inventory/production
touch inventory/group_vars/{all.yml,masters.yml,replicas.yml,standby.yml}

# Создание файлов задач для ролей
touch roles/common/tasks/main.yml
touch roles/postgresql/tasks/main.yml
touch roles/replication/tasks/main.yml
touch roles/standby/tasks/main.yml

# Создаем пустые файлы .keep в каждом каталоге
for role in common postgresql replication standby; do
  for dir in handlers templates files vars; do
    touch "roles/$role/$dir/.keep"
  done
done
```
### Установка правильных прав доступа
```bash
# Установка прав на директории (755 - владелец читает/пишет/исполняет, группа и другие - читают/исполняют)
find . -type d -exec chmod 755 {} \;

# Установка прав на файлы (644 - владелец читает/пишет, группа и другие - только читают)
find . -type f -exec chmod 644 {} \;

# Специальные права для файлов с паролями (если будут созданы)
chmod 600 inventory/group_vars/all.yml
```

```bash
tree -a
postgresql-cluster/
├── inventory
│   ├── group_vars
│   │   ├── all.yml
│   │   ├── masters.yml
│   │   ├── replicas.yml
│   │   └── standby.yml
│   └── production
├── requirements.yml
├── roles
│   ├── common
│   │   ├── files
│   │   │   └── .keep
│   │   ├── handlers
│   │   │   └── .keep
│   │   ├── tasks
│   │   │   ├── hosts.yml
│   │   │   └── main.yml
│   │   ├── templates
│   │   │   ├── hosts.j2
│   │   │   └── .keep
│   │   └── vars
│   │       └── .keep
│   ├── postgresql
│   │   ├── files
│   │   │   └── .keep
│   │   ├── handlers
│   │   │   ├── .keep
│   │   │   └── main.yml
│   │   ├── tasks
│   │   │   ├── main.yml
│   │   │   └── pre_tasks.yml
│   │   ├── templates
│   │   │   └── .keep
│   │   └── vars
│   │       └── .keep
│   ├── replication
│   │   ├── files
│   │   │   └── .keep
│   │   ├── handlers
│   │   │   └── .keep
│   │   ├── tasks
│   │   │   └── main.yml
│   │   ├── templates
│   │   │   └── .keep
│   │   └── vars
│   │       └── .keep
│   └── standby
│       ├── files
│       │   └── .keep
│       ├── handlers
│       │   └── .keep
│       ├── tasks
│       │   └── main.yml
│       ├── templates
│       │   └── .keep
│       └── vars
│           └── .keep
└── site.yml
```

Темерь можем приступить к заполнению файлов:
1. `inventory/production` - список хостов

2. `inventory/group_vars/*.yml` - переменные для групп

3. `site.yml` - основной плейбук

4. `roles/*/tasks/main.yml` - задачи для каждой роли


## 1. Инвентаризация (inventory/production)
```bash
 nano inventory/production
 ```
```ini
[masters]
vm1 ansible_host=192.168.0.103 ansible_user=nik ansible_ssh_private_key_file=~/.ssh/id_ed25519 ansible_connection=ssh
vm2 ansible_host=192.168.0.109 ansible_user=nik ansible_ssh_private_key_file=~/.ssh/id_ed25519 ansible_connection=ssh

[replicas]
vm3 ansible_host=192.168.0.110 ansible_user=nik ansible_ssh_private_key_file=~/.ssh/id_ed25519 ansible_connection=ssh

[standby]
vm4 ansible_host=192.168.0.106 ansible_user=nik ansible_ssh_private_key_file=~/.ssh/id_ed25519 ansible_connection=ssh

[postgres:children]
masters
replicas
standby

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

## 2. Групповые переменные (inventory/group_vars/all.yml)

```bash
 nano inventory/group_vars/all.yml
 ```
```yaml
---
# Основные переменные PostgreSQL
postgresql_version: "17"
postgresql_password: "12345678!"
postgresql_user: "postgres"
postgresql_db: "otus_db"
postgresql_schema: "otus_sch"

# Настройки сети
network_subnet: "192.168.0.0/24"

# Настройки подключения Ansible
ansible_connection: ssh
ansible_user: root
ansible_ssh_pass: "12345678!"
ansible_become: yes
ansible_become_method: su
ansible_become_pass: "12345678!"
```

## 3. Плейбук (site.yml)
```bash
 nano site.yml
 ```
```yaml
---
- name: Update hosts file on all nodes
  hosts: all  # Или postgres, если нужно только для PostgreSQL узлов
  become: yes
  tasks:
    - name: Update /etc/hosts with all cluster nodes
      ansible.builtin.lineinfile:
        path: /etc/hosts
        line: "{{ hostvars[item].ansible_host }} {{ item }}"
        state: present
        regexp: ".*{{ item }}$"
      loop: "{{ groups['postgres'] }}"
      tags: hosts

- name: Configure PostgreSQL cluster
  hosts: postgres
  become: yes
  collections:
    - community.postgresql
  roles:
    - common
    - postgresql

- name: Configure replication between masters
  hosts: masters
  become: yes
  roles:
    - replication

- name: Configure read replica
  hosts: replicas
  become: yes
  roles:
    - replication

- name: Configure hot standby
  hosts: standby
  become: yes
  roles:
    - standby

- hosts: postgres
  become: yes
  tasks:
    - name: Update /etc/hosts with all cluster nodes
      ansible.builtin.lineinfile:
        path: /etc/hosts
        line: "{{ hostvars[item].ansible_host }} {{ item }}"
        state: present
        regexp: ".*{{ item }}$"
      loop: "{{ groups['postgres'] }}"
      tags: hosts
```

## 4. Роли

### Роль common (roles/common/tasks/main.yml)
```bash
 nano roles/common/tasks/main.yml
 ```
```yaml
---
- name: Install dependencies
  dnf:
    name:
      - python3
      - python3-psycopg2
      - openssl
    state: present

- name: Add PostgreSQL repository
  get_url:
    url: https://download.postgresql.org/pub/repos/yum/reporpms/EL-10-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    dest: /tmp/pgdg-redhat-repo-latest.noarch.rpm

- name: Install repository RPM
  command: dnf install -y /tmp/pgdg-redhat-repo-latest.noarch.rpm --nogpgcheck
  args:
    creates: /etc/yum.repos.d/pgdg-redhat-all.repo

- name: Clean up repository RPM
  file:
    path: /tmp/pgdg-redhat-repo-latest.noarch.rpm
    state: absent

- name: Clean DNF cache
  command: dnf clean all

- name: Make cache
  command: dnf makecache
```

### Роль postgresql (roles/postgresql/tasks/main.yml)
```bash
 nano roles/postgresql/tasks/main.yml
 ```
```yaml
---
# 1. Подготовка директории
- name: Clean existing data directory on vm4
  become: yes
  file:
    path: "/var/lib/pgsql/17/otus"
    state: absent
  when: inventory_hostname == 'vm4'
  ignore_errors: yes

- name: Ensure data directory exists
  become: yes
  file:
    path: "/var/lib/pgsql/17/otus"
    state: directory
    owner: postgres
    group: postgres
    mode: '0700'
  when: inventory_hostname == 'vm4'

2. Инициализация кластера
- name: Initialize PostgreSQL cluster
  become: yes
  become_method: sudo
  become_user: postgres
  command: >
    /usr/pgsql-17/bin/initdb
    -D /var/lib/pgsql/17/otus
    --locale=ru_RU.UTF-8
    --encoding=UTF8
    --data-checksums
  when:
    - inventory_hostname == 'vm4'
    - not lookup('file', '/var/lib/pgsql/17/otus/PG_VERSION', errors='ignore')
  args:
    creates: "/var/lib/pgsql/17/otus/PG_VERSION"
  register: init_result
  changed_when: "'Готово' in init_result.stdout_lines"

- name: Secure PostgreSQL installation
  become: yes
  become_user: postgres
  command: >
    psql -c "ALTER USER postgres WITH PASSWORD '{{ 12345678! }}';"
  when:
    - inventory_hostname == 'vm4'
#    - initdb_result is changed
    - initdb_result.rc == 0  # Проверяем успешное завершение инициализации
  register: alter_user_result
  changed_when: alter_user_result.rc == 0

# 3. Конфигурация PostgreSQL
- name: Configure basic settings
  become: yes
  blockinfile:
    path: "/var/lib/pgsql/17/otus/postgresql.conf"
    block: |
      listen_addresses = '*'
      port = 5432
      wal_level = replica
      max_wal_senders = 10
      hot_standby = on
  when: inventory_hostname == 'vm4'

- name: Configure authentication
  become: yes
  blockinfile:
    path: "/var/lib/pgsql/17/otus/pg_hba.conf"
    block: |
      host    all             all             0.0.0.0/0            md5
      host    replication     all             0.0.0.0/0            md5
  when: inventory_hostname == 'vm4'

# 4. Настройка репликации (специфичная для вашего кластера)
- name: Configure pg_hba.conf for replication
  become: yes
  lineinfile:
    path: "/var/lib/pgsql/17/otus/pg_hba.conf"
    line: "host replication {{ replication_user }} {{ vm3_ip }}/32 md5"
    state: present
  when: inventory_hostname == 'vm4'

# 5. Запуск службы
- name: Start PostgreSQL service
  ansible.builtin.service:
    name: postgresql-17
    state: started
    enabled: yes
  when: inventory_hostname == 'vm4'

# 6. Оригинальные задачи по работе с таблицами
- name: Check if test table exists
  community.postgresql.postgresql_query:
    db: "{{ postgresql_db }}"
    query: SELECT 1 FROM information_schema.tables WHERE table_schema = '{{ postgresql_schema }}' AND table_name = 'test'
    login_user: postgres
    login_password: ""
  register: test_table_exists
  changed_when: false
  ignore_errors: yes

- name: Create test table if not exists
  community.postgresql.postgresql_query:
    db: "{{ postgresql_db }}"
    query: |
      CREATE TABLE IF NOT EXISTS "{{ postgresql_schema }}"."test" (
        id SERIAL PRIMARY KEY,
                data TEXT
      )
    login_user: postgres
    login_password: ""
  when: not test_table_exists.rowcount|default(0) > 0

- name: Check if test2 table exists
  community.postgresql.postgresql_query:
    db: "{{ postgresql_db }}"
    query: SELECT 1 FROM information_schema.tables WHERE table_schema = '{{ postgresql_schema }}' AND table_name = 'test2'
    login_user: postgres
    login_password: ""
  register: test2_table_exists
  changed_when: false
  ignore_errors: yes

- name: Create test2 table if not exists
  community.postgresql.postgresql_query:
    db: "{{ postgresql_db }}"
    query: |
      CREATE TABLE IF NOT EXISTS "{{ postgresql_schema }}"."test2" (
        id SERIAL PRIMARY KEY,
        data TEXT
      )
    login_user: postgres
    login_password: ""
  when: not test2_table_exists.rowcount|default(0) > 0
```

### Роль replication (roles/replication/tasks/main.yml)
```bash
 nano roles/replication/tasks/main.yml
 ```

```yaml
---
- name: Create test table on vm1 (write master)
  community.postgresql.postgresql_query:
    db: "{{ postgresql_db }}"
    query: |
      CREATE TABLE IF NOT EXISTS "{{ postgresql_schema }}"."test" (
        id SERIAL PRIMARY KEY,
        data TEXT
      )
    login_user: postgres
    login_password: ""
  when: inventory_hostname == 'vm1'

- name: Create test2 table on vm2 (write master)
  community.postgresql.postgresql_query:
    db: "{{ postgresql_db }}"
    query: |
      CREATE TABLE IF NOT EXISTS "{{ postgresql_schema }}"."test2" (
        id SERIAL PRIMARY KEY,
        data TEXT
      )
    login_user: postgres
    login_password: ""
  when: inventory_hostname == 'vm2'

- name: Create publication for test table on vm1
  community.postgresql.postgresql_publication:
    name: pub_test
    db: "{{ postgresql_db }}"
    tables:
      - "{{ postgresql_schema }}.test"
    login_user: postgres
    login_password: ""
  when: inventory_hostname == 'vm1'

- name: Create publication for test2 table on vm2
  community.postgresql.postgresql_publication:
    name: pub_test2
    db: "{{ postgresql_db }}"
    tables:
      - "{{ postgresql_schema }}.test2"
    login_user: postgres
    login_password: ""
  when: inventory_hostname == 'vm2'

- name: Create subscription on vm2 to vm1
  community.postgresql.postgresql_subscription:
    name: sub_test
    db: "{{ postgresql_db }}"
    publications:
      - pub_test
    connparams:
      host: vm1
      user: "{{ postgresql_user }}"
      password: "{{ postgresql_password }}"
      dbname: "{{ postgresql_db }}"
    login_user: postgres
    login_password: ""
  when: inventory_hostname == 'vm2'

- name: Create subscription on vm1 to vm2
  community.postgresql.postgresql_subscription:
    name: sub_test2
    db: "{{ postgresql_db }}"
    publications:
      - pub_test2
    connparams:
      host: vm2
      user: "{{ postgresql_user }}"
      password: "{{ postgresql_password }}"
      dbname: "{{ postgresql_db }}"
    login_user: postgres
    login_password: ""
  when: inventory_hostname == 'vm1'
```

### Роль standby (roles/standby/tasks/main.yml)

```bash
 nano roles/standby/tasks/main.yml
 ```
```yaml
---
- name: Stop PostgreSQL service
  service:
    name: "postgresql-{{ postgresql_version }}"
    state: stopped

- name: Remove existing data directory
  file:
    path: "/var/lib/pgsql/{{ postgresql_version }}/data"
    state: absent

- name: Create base backup from vm3
  command: >
    sudo -u postgres /usr/pgsql-{{ postgresql_version }}/bin/pg_basebackup
    -h vm3 -U {{ postgresql_user }} -D /var/lib/pgsql/{{ postgresql_version }}/data
    -P -R -X stream
  environment:
    PGPASSWORD: "{{ postgresql_password }}"

- name: Configure standby mode
  lineinfile:
    path: "/var/lib/pgsql/{{ postgresql_version }}/data/postgresql.conf"
    line: "primary_conninfo = 'host=vm3 user={{ postgresql_user }} password={{ postgresql_password }}'"
    backup: yes

- name: Create standby signal file
  file:
    path: "/var/lib/pgsql/{{ postgresql_version }}/data/standby.signal"
    state: touch
    owner: postgres
    group: postgres
    mode: '0640'

- name: Start PostgreSQL service
  service:
    name: "postgresql-{{ postgresql_version }}"
    state: started
```
## Сгенерируйте SSH-ключ на управляющей машине с Ansible:
```bash
ssh-keygen -t ed25519
```
Скопируем ключ на все VM:
```bash
ssh-copy-id root@192.168.0.103
ssh-copy-id root@192.168.0.109
ssh-copy-id root@192.168.0.110
ssh-copy-id root@192.168.0.106
```
## 5. Запуск Ansible


```bash
# Проверка доступности хостов
ansible -i inventory/production -m ping all --ask-pass

## П.С., если система не сможет подключиться и вернётся с ошибкой о необходимости установит sshpass, то установим её: sudo dnf install -y sshpass

# Запуск плейбука
ansible-playbook -i inventory/production site.yml --ask-pass
```

## Особенности реализации

1. **Модульная структура**: Разделение на роли позволяет легко управлять конфигурацией для разных типов узлов.

2. **Идемпотентность**: Все задачи написаны с учетом идемпотентности, что позволяет безопасно запускать плейбук многократно.

3. **Безопасность**: Пароли и чувствительные данные можно вынести в Ansible Vault.

4. **Гибкость**: Конфигурация параметризована через переменные, что позволяет легко адаптировать под разные окружения.

5. **Поддержка разных типов репликации**:
   - Логическая репликация между VM1 и VM2
   - Логическая репликация на VM3
   - Физическая репликация на VM4

Для работы этого плейбука потребуется установленный на управляющей машине Ansible и Python-модуль `community.postgresql` .