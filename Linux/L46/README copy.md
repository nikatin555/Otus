Да, структура каталогов правильная и полная для выполнения задания. Все необходимые файлы присутствуют. 

Давайте проверим содержимое каждого файла и при необходимости дополним:

## 1. Проверка и дополнение файлов

**ansible/roles/install_postgres/tasks/main.yml:**
```yaml
---
- name: Install PostgreSQL 14 and dependencies
  apt:
    name:
      - postgresql-14
      - postgresql-contrib-14
      - python3-psycopg2
    state: present
    update_cache: yes

- name: Ensure PostgreSQL service is running and enabled
  service:
    name: postgresql
    state: started
    enabled: yes
```

**ansible/roles/postgres_replication/handlers/main.yml:**
```yaml
---
- name: restart postgresql
  service:
    name: postgresql
    state: restarted
```

**ansible/roles/postgres_replication/tasks/main.yml:**
```yaml
---
- name: Install additional PostgreSQL packages
  apt:
    name:
      - postgresql-14-pglogical
    state: present

- name: Create replicator user on master
  become_user: postgres
  postgresql_user:
    name: replication
    password: "{{ replicator_password }}"
    role_attr_flags: REPLICATION,LOGIN
    state: present
  when: ansible_hostname == "node1"

- name: Configure PostgreSQL on master
  template:
    src: postgresql.conf.j2
    dest: /etc/postgresql/14/main/postgresql.conf
    owner: postgres
    group: postgres
    mode: '0644'
  when: ansible_hostname == "node1"
  notify: restart postgresql

- name: Configure pg_hba on master
  template:
    src: pg_hba.conf.j2
    dest: /etc/postgresql/14/main/pg_hba.conf
    owner: postgres
    group: postgres
    mode: '0640'
  when: ansible_hostname == "node1"
  notify: restart postgresql

- name: Stop PostgreSQL on slave before setup
  service:
    name: postgresql
    state: stopped
  when: ansible_hostname == "node2"

- name: Remove existing data directory on slave
  file:
    path: /var/lib/postgresql/14/main
    state: absent
  when: ansible_hostname == "node2"

- name: Create base backup from master to slave
  become_user: postgres
  shell: |
    pg_basebackup -h {{ master_ip }} -U replication -D /var/lib/postgresql/14/main/ -R -P -X stream -S replication_slot
  environment:
    PGPASSWORD: "{{ replicator_password }}"
  when: ansible_hostname == "node2"
  args:
    creates: /var/lib/postgresql/14/main/postgresql.conf

- name: Configure PostgreSQL on slave
  template:
    src: postgresql.conf.j2
    dest: /etc/postgresql/14/main/postgresql.conf
    owner: postgres
    group: postgres
    mode: '0644'
  when: ansible_hostname == "node2"
  notify: restart postgresql

- name: Start PostgreSQL on slave
  service:
    name: postgresql
    state: started
    enabled: yes
  when: ansible_hostname == "node2"

- name: Create replication slot on master
  become_user: postgres
  postgresql_query:
    query: "SELECT pg_create_physical_replication_slot('replication_slot', true);"
  when: ansible_hostname == "node1"
  ignore_errors: yes

- name: Verify replication status on master
  become_user: postgres
  shell: |
    psql -c "SELECT * FROM pg_stat_replication;"
  when: ansible_hostname == "node1"
  register: replication_status

- name: Show replication status
  debug:
    var: replication_status.stdout
  when: ansible_hostname == "node1"
```

## 2. Дополним шаблоны конфигурации

**ansible/roles/postgres_replication/templates/postgresql.conf.j2:**
```conf
# Database Configuration
listen_addresses = 'localhost, {{ master_ip if ansible_hostname == "node1" else slave_ip }}'
port = 5432
max_connections = 100

# Memory Settings
shared_buffers = 128MB
work_mem = 4MB
maintenance_work_mem = 64MB

# WAL Settings
wal_level = replica
max_wal_senders = 3
max_replication_slots = 3
wal_keep_size = 1GB
max_wal_size = 1GB
min_wal_size = 80MB

# Replication Settings
hot_standby = on
hot_standby_feedback = on
max_standby_archive_delay = 300s
max_standby_streaming_delay = 300s

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%a.log'
log_rotation_age = 1d
log_rotation_size = 0
log_truncate_on_rotation = on
log_line_prefix = '%m [%p] '

# Authentication
password_encryption = scram-sha-256

# Timezone
timezone = 'UTC'
```

**ansible/roles/postgres_replication/templates/pg_hba.conf.j2:**
```conf
# PostgreSQL Client Authentication Configuration File

# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     peer

# IPv4 local connections:
host    all             all             127.0.0.1/32            scram-sha-256

# IPv6 local connections:
host    all             all             ::1/128                 scram-sha-256

# Replication connections from localhost
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256

# Replication connections from network
host    replication     replication     {{ master_ip }}/32      scram-sha-256
host    replication     replication     {{ slave_ip }}/32       scram-sha-256

# Allow connections from private network
host    all             all             192.168.57.0/24         scram-sha-256
```

## 3. Дополним конфигурацию Barman

**ansible/roles/install_barman/templates/barman.conf.j2:**
```conf
[barman]
barman_home = /var/lib/barman
barman_user = barman
log_file = /var/log/barman/barman.log
configuration_files_directory = /etc/barman.d
compression = gzip
backup_method = postgres
retention_policy = REDUNDANCY 2
immediate_checkpoint = true
network_compression = true
last_backup_maximum_age = 1 DAYS
```

**ansible/roles/install_barman/templates/node1.conf.j2:**
```conf
[node1]
description = "PostgreSQL Master Node - node1"
conninfo = host={{ master_ip }} user=barman dbname=postgres port=5432
ssh_command = ssh postgres@{{ master_ip }}
backup_method = postgres
streaming_conninfo = host={{ master_ip }} user=streaming_barman dbname=postgres port=5432
streaming_archiver = on
slot_name = barman
create_slot = auto
archiver = on
retention_policy_mode = auto
retention_policy = RECOVERY WINDOW OF 7 days
wal_retention_policy = main
path_prefix = "/usr/lib/postgresql/14/bin"
```

## 4. Дополним defaults переменные

**ansible/roles/postgres_replication/defaults/main.yml:**
```yaml
---
replicator_password: 'Otus2022!'
master_ip: '192.168.57.11'
slave_ip: '192.168.57.12'
```

**ansible/roles/install_barman/defaults/main.yml:**
```yaml
---
master_ip: '192.168.57.11'
barman_ip: '192.168.57.13'
barman_user_password: 'Otus2022!'
```

## 5. Финальная проверка структуры

После дополнений структура должна выглядеть так:

```
.
├── ansible
│   ├── inventory.ini
│   ├── provision.yml
│   └── roles
│       ├── install_barman
│       │   ├── defaults
│       │   │   └── main.yml
│       │   ├── tasks
│       │   │   └── main.yml
│       │   └── templates
│       │       ├── barman.conf.j2
│       │       └── node1.conf.j2
│       ├── install_postgres
│       │   └── tasks
│       │       └── main.yml
│       └── postgres_replication
│           ├── defaults
│           │   └── main.yml
│           ├── handlers
│           │   └── main.yml
│           ├── tasks
│           │   └── main.yml
│           └── templates
│               ├── pg_hba.conf.j2
│               └── postgresql.conf.j2
└── Vagrantfile
```

Теперь структура полная и содержит все необходимые файлы для настройки:
- Hot standby репликации PostgreSQL с использованием слотов
- Резервного копирования с помощью Barman
- Автоматической настройки через Ansible

Все файлы на месте, можно запускать `vagrant up`.
fix_cluster_config_only.sh - помог!!!!

./final_verification.sh !!!!