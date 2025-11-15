# 44.  MySQL: Backup + Репликация 

## Домашнее задание

Репликация mysql

**Цель:**

Поработать с реаликацией MySQL.

Описание/Пошаговая инструкция выполнения домашнего задания:

Для выполнения домашнего задания используйте [методичку](https://drive.google.com/file/d/139irfqsbAxNMjVcStUN49kN7MXAJr_z9/view?usp=share_link)


**Что нужно сделать?**

1. В материалах приложены ссылки на вагрант для репликации и дамп базы bet.dmp

2. Базу развернуть на мастере и настроить так, чтобы реплицировались таблицы:


| bookmaker          | <br>
| competition        | <br>
| market             | <br>
| odds               | <br>
| outcome            | <br>


3. Настроить GTID репликацию

варианты которые принимаются к сдаче

    рабочий вагрантафайл
    скрины или логи SHOW TABLES
    конфиги*


4. Пример в логе изменения строки и появления строки на реплике*


Я подготовлю решение для настройки MySQL репликации с использованием современных технологий. Вот полный комплект файлов:

## 1. Vagrantfile

```ruby
ENV['VAGRANT_SERVER_URL'] = 'https://vagrant.elab.pro'

Vagrant.configure("2") do |config|
  config.vm.define "mysql-master" do |master|
    master.vm.box = "almalinux/9"
    master.vm.hostname = "mysql-master"
    master.vm.network "private_network", ip: "192.168.56.10"
    master.vm.provider "virtualbox" do |vb|
      vb.memory = 4096
      vb.cpus = 2
    end
  end

  config.vm.define "mysql-slave" do |slave|
    slave.vm.box = "almalinux/9"
    slave.vm.hostname = "mysql-slave"
    slave.vm.network "private_network", ip: "192.168.56.11"
    slave.vm.provider "virtualbox" do |vb|
      vb.memory = 4096
      vb.cpus = 2
    end
  end
end
```

## 2. inventory.ini

```ini
[mysql_servers]
mysql-master ansible_host=192.168.56.10 ansible_user=vagrant ansible_ssh_private_key_file=.vagrant/machines/mysql-master/virtualbox/private_key
mysql-slave ansible_host=192.168.56.11 ansible_user=vagrant ansible_ssh_private_key_file=.vagrant/machines/mysql-slave/virtualbox/private_key

[master]
mysql-master

[slave]
mysql-slave
```

## 3. playbook.yml

```yaml
---
- name: Configure MySQL Master-Slave replication with GTID
  hosts: all
  become: yes
  vars:
    mysql_root_password: "YourStrongPassword123!"
    mysql_repl_user: "repl"
    mysql_repl_password: "!OtusLinux2024"
    mysql_version: "8.0"
    bet_database: "bet"

  tasks:
    - name: Install EPEL repository
      dnf:
        name: epel-release
        state: present

    - name: Install MySQL 8.0 server
      dnf:
        name:
          - mysql-server
          - mysql
        state: present

    - name: Start and enable MySQL service
      systemd:
        name: mysqld
        state: started
        enabled: yes

    - name: Ensure MySQL data directory exists
      file:
        path: /var/lib/mysql
        state: directory
        owner: mysql
        group: mysql
        mode: '0755'

    - name: Secure MySQL installation
      shell: |
        # Get temporary root password
        temp_password=$(sudo grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
        
        # Change root password
        mysqladmin -u root -p"$temp_password" password "{{ mysql_root_password }}"
        
        # Remove anonymous users
        mysql -u root -p"{{ mysql_root_password }}" -e "DELETE FROM mysql.user WHERE User='';"
        
        # Remove remote root login
        mysql -u root -p"{{ mysql_root_password }}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
        
        # Remove test database
        mysql -u root -p"{{ mysql_root_password }}" -e "DROP DATABASE IF EXISTS test;"
        mysql -u root -p"{{ mysql_root_password }}" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
        
        # Reload privileges
        mysql -u root -p"{{ mysql_root_password }}" -e "FLUSH PRIVILEGES;"
      args:
        executable: /bin/bash
      register: secure_mysql
      failed_when: secure_mysql.rc != 0 and "mysqladmin: connect" not in secure_mysql.stderr

    - name: Wait for MySQL to be ready
      wait_for:
        port: 3306
        host: 127.0.0.1
        delay: 5
        timeout: 60

- name: Configure MySQL Master
  hosts: master
  become: yes
  vars:
    server_id: 1

  tasks:
    - name: Create MySQL configuration directory
      file:
        path: /etc/my.cnf.d
        state: directory
        mode: '0755'

    - name: Configure MySQL master
      template:
        src: templates/master.cnf.j2
        dest: /etc/my.cnf.d/master.cnf
        owner: root
        group: root
        mode: '0644'
      notify: restart mysql

    - name: Restart MySQL service
      systemd:
        name: mysqld
        state: restarted

    - name: Wait for MySQL to restart
      wait_for:
        port: 3306
        host: 127.0.0.1
        delay: 10
        timeout: 60

    - name: Create replication user on master
      mysql_user:
        name: "{{ hostvars['localhost']['mysql_repl_user'] }}"
        password: "{{ hostvars['localhost']['mysql_repl_password'] }}"
        host: "%"
        priv: "*.*:REPLICATION SLAVE"
        state: present
        login_user: root
        login_password: "{{ hostvars['localhost']['mysql_root_password'] }}"

    - name: Create bet database
      mysql_db:
        name: "{{ hostvars['localhost']['bet_database'] }}"
        state: present
        login_user: root
        login_password: "{{ hostvars['localhost']['mysql_root_password'] }}"

    - name: Copy database dump to master
      copy:
        src: files/bet-224190-feff6d.dmp
        dest: /tmp/bet.dmp
        owner: root
        group: root
        mode: '0644'

    - name: Import database dump
      shell: |
        mysql -u root -p"{{ hostvars['localhost']['mysql_root_password'] }}" {{ hostvars['localhost']['bet_database'] }} < /tmp/bet.dmp
      args:
        executable: /bin/bash

    - name: Get master status
      mysql_query:
        query: SHOW MASTER STATUS
        login_user: root
        login_password: "{{ hostvars['localhost']['mysql_root_password'] }}"
      register: master_status

    - name: Show master status
      debug:
        var: master_status

    - name: Create dump for slave
      shell: |
        mysqldump --all-databases --triggers --routines --master-data \
        --ignore-table={{ hostvars['localhost']['bet_database'] }}.events_on_demand \
        --ignore-table={{ hostvars['localhost']['bet_database'] }}.v_same_event \
        -uroot -p"{{ hostvars['localhost']['mysql_root_password'] }}" > /tmp/master.sql
      args:
        executable: /bin/bash

    - name: Copy dump to slave
      synchronize:
        src: /tmp/master.sql
        dest: /tmp/master.sql
        delegate_to: "{{ groups['slave'][0] }}"

- name: Configure MySQL Slave
  hosts: slave
  become: yes
  vars:
    server_id: 2

  tasks:
    - name: Create MySQL configuration directory
      file:
        path: /etc/my.cnf.d
        state: directory
        mode: '0755'

    - name: Configure MySQL slave
      template:
        src: templates/slave.cnf.j2
        dest: /etc/my.cnf.d/slave.cnf
        owner: root
        group: root
        mode: '0644'
      notify: restart mysql

    - name: Restart MySQL service
      systemd:
        name: mysqld
        state: restarted

    - name: Wait for MySQL to restart
      wait_for:
        port: 3306
        host: 127.0.0.1
        delay: 10
        timeout: 60

    - name: Import master dump
      shell: |
        mysql -u root -p"{{ hostvars['localhost']['mysql_root_password'] }}" < /tmp/master.sql
      args:
        executable: /bin/bash

    - name: Configure replication
      mysql_replication:
        mode: changemaster
        master_host: "{{ groups['master'][0] }}"
        master_port: 3306
        master_user: "{{ hostvars['localhost']['mysql_repl_user'] }}"
        master_password: "{{ hostvars['localhost']['mysql_repl_password'] }}"
        master_auto_position: 1
        login_user: root
        login_password: "{{ hostvars['localhost']['mysql_root_password'] }}"

    - name: Start replication
      mysql_replication:
        mode: startslave
        login_user: root
        login_password: "{{ hostvars['localhost']['mysql_root_password'] }}"

    - name: Check replication status
      mysql_query:
        query: SHOW SLAVE STATUS
        login_user: root
        login_password: "{{ hostvars['localhost']['mysql_root_password'] }}"
      register: slave_status

    - name: Show slave status
      debug:
        var: slave_status

  handlers:
    - name: restart mysql
      systemd:
        name: mysqld
        state: restarted
```

## 4. Конфигурационные шаблоны

**templates/master.cnf.j2**
```ini
[mysqld]
# Basic settings
server-id = {{ server_id }}
datadir = /var/lib/mysql
socket = /var/lib/mysql/mysql.sock
log-error = /var/log/mysqld.log
pid-file = /var/run/mysqld/mysqld.pid

# Binary logging
log-bin = mysql-bin
binlog-format = ROW
expire-logs-days = 10
max-binlog-size = 100M

# GTID
gtid-mode = ON
enforce-gtid-consistency = ON

# Replication settings
binlog-do-db = {{ hostvars['localhost']['bet_database'] }}
replicate-do-db = {{ hostvars['localhost']['bet_database'] }}

# Ignore system databases for replication
binlog-ignore-db = mysql
binlog-ignore-db = information_schema
binlog-ignore-db = performance_schema
binlog-ignore-db = sys

[client]
socket = /var/lib/mysql/mysql.sock
```

**templates/slave.cnf.j2**
```ini
[mysqld]
# Basic settings
server-id = {{ server_id }}
datadir = /var/lib/mysql
socket = /var/lib/mysql/mysql.sock
log-error = /var/log/mysqld.log
pid-file = /var/run/mysqld/mysqld.pid

# Binary logging (for potential slave promotion)
log-bin = mysql-bin
binlog-format = ROW

# GTID
gtid-mode = ON
enforce-gtid-consistency = ON

# Replication settings
relay-log = mysql-relay-bin
read-only = 1
super-read-only = 1

# Tables to ignore in replication
replicate-ignore-table = {{ hostvars['localhost']['bet_database'] }}.events_on_demand
replicate-ignore-table = {{ hostvars['localhost']['bet_database'] }}.v_same_event

# Replicate only specific tables
replicate-do-table = {{ hostvars['localhost']['bet_database'] }}.bookmaker
replicate-do-table = {{ hostvars['localhost']['bet_database'] }}.competition
replicate-do-table = {{ hostvars['localhost']['bet_database'] }}.market
replicate-do-table = {{ hostvars['localhost']['bet_database'] }}.odds
replicate-do-table = {{ hostvars['localhost']['bet_database'] }}.outcome

[client]
socket = /var/lib/mysql/mysql.sock
```

## 5. Скрипт проверки репликации

**check_replication.sql**
```sql
-- Проверка на мастере
SHOW MASTER STATUS;

-- Проверка на слейве
SHOW SLAVE STATUS\G

-- Проверка реплицируемых таблиц
USE bet;
SHOW TABLES;

-- Проверка GTID
SELECT @@GLOBAL.GTID_MODE;

-- Тест репликации: вставка на мастере
INSERT INTO bookmaker (bookmaker_name) VALUES ('test_bookmaker');
SELECT * FROM bookmaker WHERE bookmaker_name = 'test_bookmaker';
```

## 6. Инструкция по запуску

```bash
# 1. Запуск виртуальных машин
vagrant up

# 2. Настройка репликации
ansible-playbook -i inventory.ini playbook.yml

# 3. Проверка репликации
# На мастере
vagrant ssh mysql-master
sudo mysql -p < check_replication.sql

# На слейве
vagrant ssh mysql-slave
sudo mysql -p -e "SHOW SLAVE STATUS\G"
sudo mysql -p -e "USE bet; SHOW TABLES;"
```

## 7. Логи проверки репликации

После настройки вы должны увидеть:

**На мастере:**
```sql
mysql> SHOW TABLES;
+----------------+
| Tables_in_bet  |
+----------------+
| bookmaker      |
| competition    |
| events_on_demand |
| market         |
| odds           |
| outcome        |
| v_same_event   |
+----------------+
```

**На слейве:**
```sql
mysql> SHOW TABLES;
+---------------+
| Tables_in_bet |
+---------------+
| bookmaker     |
| competition   |
| market        |
| odds          |
| outcome       |
+---------------+
```

**Статус репликации:**
```sql
mysql> SHOW SLAVE STATUS\G
Slave_IO_State: Waiting for master to send event
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Replicate_Ignore_Table: bet.events_on_demand,bet.v_same_event
Retrieved_Gtid_Set: [GTID_SET]
Executed_Gtid_Set: [GTID_SET]
```

Это решение обеспечивает:
- Настройку GTID репликации в MySQL 8.0
- Репликацию только указанных таблиц
- Игнорирование таблиц events_on_demand и v_same_event
- Автоматическую установку и конфигурацию через Ansible
- Современные AlmaLinux 9 виртуальные машины


===================================================

Нужен скрипт для копирования файлов или исправить playbook.yml:
```yaml
    - name: Copy dump to slave using fetch/copy
      fetch:
        src: /tmp/master.sql
        dest: /tmp/{{ inventory_hostname }}_master.sql
        flat: yes
      delegate_to: "{{ groups['slave'][0] }}"
```
или в ручную:
```bash
bash
# На master
vagrant ssh mysql-master
sudo cp /tmp/master.sql /vagrant/

# На slave  
vagrant ssh mysql-slave
sudo cp /vagrant/master.sql /tmp/
```