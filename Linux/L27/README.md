# 27. Резервное копирование

**Домашнее задание**

Настраиваем бэкапы

**Цель:**

Настроить бэкапы.

**Описание/Пошаговая инструкция выполнения домашнего задания:**

Для выполнения домашнего задания используйте методичку


Что нужно сделать?

Настроить стенд Vagrant с двумя виртуальными машинами: backup_server и client.


Настроить удаленный бекап каталога /etc c сервера client при помощи borgbackup. Резервные копии должны соответствовать следующим критериям:

  - директория для резервных копий /var/backup. Это должна быть отдельная точка монтирования. В данном случае для демонстрации размер не принципиален, достаточно будет и 2GB; <br>
  - репозиторий дле резервных копий должен быть зашифрован ключом или паролем - на ваше усмотрение; <br>
  - имя бекапа должно содержать информацию о времени снятия бекапа;<br>
  - глубина бекапа должна быть год, хранить можно по последней копии на конец месяца, кроме последних трех.<br>
  - Последние три месяца должны содержать копии на каждый день. Т.е. должна быть правильно настроена политика удаления старых бэкапов;<br>
  - резервная копия снимается каждые 5 минут. Такой частый запуск в целях демонстрации;<br>
  - написан скрипт для снятия резервных копий. Скрипт запускается из соответствующей Cron джобы, либо systemd timer-а - на ваше усмотрение; <br>
  - настроено логирование процесса бекапа. Для упрощения можно весь вывод перенаправлять в logger с соответствующим тегом. Если настроите не в syslog, то обязательна ротация логов.

Запустите стенд на 30 минут.

Убедитесь что резервные копии снимаются.

Остановите бекап, удалите (или переместите) директорию /etc и восстановите ее из бекапа.

Для сдачи домашнего задания ожидаем настроенные стенд, логи процесса бэкапа и описание процесса восстановления.

Формат сдачи ДЗ - vagrant + ansible

Я подготовлю решение для настройки удаленного резервного копирования с использованием BorgBackup. Вот полная реализация:

## 1. Схема стенда

```
+-------------------------------------------------+
|                   VirtualBox Host               |
| +-----------------+    +---------------------+  |
| |   client VM     |    |    backup VM        |  |
| | 192.168.11.150  |    |  192.168.11.160     |  |
| | Ubuntu 22.04    |    |  Ubuntu 22.04       |  |
| |                 |    | +-----------------+ |  |
| | /etc/ (source)  |----| | /var/backup/    | |  |
| | Borg client     |    | | Borg repository | |  |
| +-----------------+    | | (encrypted)     | |  |
|                        | +-----------------+ |  |
|                        +---------------------+  |
+-------------------------------------------------+
```
```bash
#Структура каталогов:
borg-backup-project
[root@localhost l27]# tree -a
.
└── borg-backup-project
    ├── .gitignore
    ├── group_vars
    │   ├── all.yml
    │   ├── backup.yml
    │   └── client.yml
    ├── inventory.ini
    ├── playbook.yml
    ├── provision
    │   ├── backup_setup.sh
    │   └── client_setup.sh
    ├── README.md
    ├── requirements.yml
    ├── roles
    │   ├── backup-server
    │   │   ├── handlers
    │   │   │   └── main.yml
    │   │   ├── tasks
    │   │   │   └── main.yml
    │   │   └── templates
    │   │       └── borg-authorized-keys.j2
    │   └── client-server
    │       ├── files
    │       │   └── ssh-config
    │       ├── handlers
    │       │   └── main.yml
    │       ├── tasks
    │       │   └── main.yml
    │       └── templates
    │           ├── borg-backup.service.j2
    │           ├── borg-backup.sh.j2
    │           ├── borg-backup.timer.j2
    │           └── borg-logrotate.j2
    ├── .vagrant
    │   ├── machines
    │   │   ├── backup
    │   │   │   └── virtualbox
    │   │   │       ├── action_cloud_init
    │   │   │       ├── action_provision
    │   │   │       ├── action_set_name
    │   │   │       ├── box_meta
    │   │   │       ├── creator_uid
    │   │   │       ├── disk_meta
    │   │   │       ├── id
    │   │   │       ├── index_uuid
    │   │   │       ├── private_key
    │   │   │       ├── synced_folders
    │   │   │       └── vagrant_cwd
    │   │   └── client
    │   │       └── virtualbox
    │   │           ├── action_cloud_init
    │   │           ├── action_provision
    │   │           ├── action_set_name
    │   │           ├── box_meta
    │   │           ├── creator_uid
    │   │           ├── disk_meta
    │   │           ├── id
    │   │           ├── index_uuid
    │   │           ├── private_key
    │   │           ├── synced_folders
    │   │           └── vagrant_cwd
    │   └── rgloader
    │       └── loader.rb
    └── Vagrantfile

21 directories, 44 files
```
```md
# Borg Backup Project

Проект для настройки удаленного резервного копирования с использованием BorgBackup.

## Структура проекта

- `Vagrantfile` - конфигурация виртуальных машин
- `playbook.yml` - основной плейбук Ansible
- `inventory.ini` - инвентарь хостов
- `roles/` - роли Ansible
- `group_vars/` - переменные для групп хостов
```
## 2. Vagrantfile

```ruby
ENV['VAGRANT_SERVER_URL'] = 'https://vagrant.elab.pro'

Vagrant.configure("2") do |config|
  config.vm.define "backup" do |backup|
    backup.vm.box = "ubuntu/jammy64"
    backup.vm.hostname = "backup"
    backup.vm.network "private_network", ip: "192.168.11.160"

    backup.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.name = "backup-server"
    end

    backup.vm.disk :disk, size: "2GB", name: "backup_disk", primary: false
    backup.vm.provision "shell", path: "provision/backup_setup.sh"
  end

  config.vm.define "client" do |client|
    client.vm.box = "ubuntu/jammy64"
    client.vm.hostname = "client"
    client.vm.network "private_network", ip: "192.168.11.150"

    client.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.name = "client-server"
    end

    client.vm.provision "shell", path: "provision/client_setup.sh"
  end
end
```

## 3. Ansible плейбук

`playbook.yml`:
```yaml
---
- name: Configure Borg Backup Infrastructure
  hosts: all
  become: yes
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

- name: Configure Backup Server
  hosts: backup
  become: yes
  roles:
    - backup-server

- name: Configure Client Server
  hosts: client
  become: yes
  roles:
    - client-server

- name: Final configuration
  hosts: client
  become: yes
  tasks:
    - name: Initialize Borg repository
      command: |
        ssh -i /root/.ssh/borg_key -o StrictHostKeyChecking=no borg@192.168.11.160 \
        "borg init --encryption=repokey /var/backup 2>/dev/null || true"
      environment:
        BORG_PASSPHRASE: "{{ borg_passphrase }}"
```

## 4. Скрипты provisioning

`provision/backup_setup.sh`:
```bash
#!/bin/bash
apt-get update
apt-get upgrade -y
apt-get install -y borgbackup
```

`provision/client_setup.sh`:
```bash
#!/bin/bash
apt-get update
apt-get upgrade -y
apt-get install -y borgbackup
```
## 5. inventory.ini:
```ini
192.168.11.160

[client]
192.168.11.150

[all:vars]
ansible_user=vagrant
ansible_ssh_private_key_file=~/.vagrant.d/insecure_private_key
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```
## 6. group_vars
group_vars/all.yml:
```yaml
---
# Общие переменные
borg_user: borg
borg_backup_dir: /var/backup
borg_passphrase: "Otus1234"
backup_server_ip: 192.168.11.160
client_server_ip: 192.168.11.150
backup_target: /etc
```
group_vars/client.yml:
```yaml
---
# Переменные для client сервера
backup_interval: "5min"
retention_daily: 90
retention_monthly: 12
retention_yearly: 1
```
group_vars/backup.yml:
```yaml
---
# Переменные для backup сервера
backup_disk_size: "2GB"
```
## 7. requirements.yml
```yaml
---
# Ansible role dependencies
- src: git+https://github.com/geerlingguy/ansible-role-ssh
  version: master
  name: geerlingguy.ssh
```
## 8. roles

roles/backup-server/tasks/main.yml:
```yaml
---
- name: Install borgbackup
  apt:
    name: borgbackup
    state: present

- name: Create borg user
  user:
    name: "{{ borg_user }}"
    shell: /bin/bash
    home: "/home/{{ borg_user }}"
    system: no
    create_home: yes

- name: Prepare backup disk
  block:
    - name: Find backup disk
      command: lsblk -n -o NAME,SIZE | grep sd[b-z]
      register: disk_check
      changed_when: false

    - name: Create filesystem on backup disk
      filesystem:
        fstype: ext4
        dev: "/dev/{{ (disk_check.stdout_lines[0].split())[0] }}"
      when: disk_check.stdout_lines | length > 0

    - name: Create mount point
      file:
        path: "{{ borg_backup_dir }}"
        state: directory
        mode: '0755'

    - name: Mount backup disk
      mount:
        path: "{{ borg_backup_dir }}"
        src: "/dev/{{ (disk_check.stdout_lines[0].split())[0] }}"
        fstype: ext4
        state: mounted

    - name: Set ownership of backup directory
      file:
        path: "{{ borg_backup_dir }}"
        owner: "{{ borg_user }}"
        group: "{{ borg_user }}"
        recurse: yes

- name: Setup SSH directory for borg
  file:
    path: "/home/{{ borg_user }}/.ssh"
    state: directory
    owner: "{{ borg_user }}"
    group: "{{ borg_user }}"
    mode: '0700'

- name: Create authorized_keys template
  template:
    src: borg-authorized-keys.j2
    dest: "/home/{{ borg_user }}/.ssh/authorized_keys"
    owner: "{{ borg_user }}"
    group: "{{ borg_user }}"
    mode: '0600'
```
roles/backup-server/templates/borg-authorized-keys.j2:
```
# Borg backup authorized keys
{{ client_ssh_public_key }}
```
roles/client-server/files/ssh-config:
```
Host backup-server
  HostName {{ backup_server_ip }}
  User {{ borg_user }}
  IdentityFile /root/.ssh/borg_key
  StrictHostKeyChecking no
```
 roles/client-server/tasks/main.yml
 ```yaml
 ---
- name: Install borgbackup
  apt:
    name: borgbackup
    state: present

- name: Generate SSH key for borg
  command: ssh-keygen -t rsa -b 4096 -f /root/.ssh/borg_key -N ""
  args:
    creates: /root/.ssh/borg_key

- name: Read SSH public key
  slurp:
    src: /root/.ssh/borg_key.pub
  register: ssh_public_key

- name: Set fact for client SSH public key
  set_fact:
    client_ssh_public_key: "{{ ssh_public_key.content | b64decode }}"

- name: Create backup script directory
  file:
    path: /opt/backup
    state: directory
    mode: '0755'

- name: Deploy backup script
  template:
    src: borg-backup.sh.j2
    dest: /opt/backup/borg-backup.sh
    mode: '0755'

- name: Deploy systemd service
  template:
    src: borg-backup.service.j2
    dest: /etc/systemd/system/borg-backup.service
    mode: '0644'

- name: Deploy systemd timer
  template:
    src: borg-backup.timer.j2
    dest: /etc/systemd/system/borg-backup.timer
    mode: '0644'

- name: Deploy logrotate configuration
  template:
    src: borg-logrotate.j2
    dest: /etc/logrotate.d/borg-backup
    mode: '0644'

- name: Enable and start timer
  systemd:
    name: borg-backup.timer
    enabled: yes
    state: started
    daemon_reload: yes

- name: Copy SSH config
  copy:
    src: files/ssh-config
    dest: /root/.ssh/config
    mode: '0600'
 ```

 roles/client-server/templates/borg-backup.sh.j2:

 ```bash
#!/bin/bash

export BORG_PASSPHRASE='Otus1234'
export BORG_RSH='ssh -i /root/.ssh/borg_key -o StrictHostKeyChecking=no'
REPO="borg@192.168.11.160:/var/backup"

log() {
  logger -t borg-backup "$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> /var/log/borg-backup.log
}

log "Starting backup of /etc"
if borg create --stats --list $REPO::etc-{now:%Y-%m-%d_%H:%M:%S} /etc; then
  log "Backup created successfully"
else
  log "Backup creation failed"
  exit 1
fi

log "Starting prune operation"
if borg prune --keep-daily 90 --keep-monthly 12 --keep-yearly 1 $REPO; then
  log "Prune operation completed successfully"
else
  log "Prune operation failed"
  exit 1
fi

log "Backup process completed"
 ```

roles/client-server/templates/borg-backup.timer.j2:
```bash
[Unit]
Description=Run Borg Backup every {{ backup_interval }}
Requires=borg-backup.service

[Timer]
OnBootSec={{ backup_interval }}
OnUnitActiveSec={{ backup_interval }}

[Install]
WantedBy=timers.target
```

## Использование

```bash
#Запустить виртуальные машины:
vagrant up
# Запустить Ansible:
ansible-playbook -i inventory.ini playbook.yml --ask-pass
```
```

### Проверка бэкапов (через 30 минут):
```bash
vagrant ssh client
# Посмотрим все архивы
borg list borg@192.168.11.160:/var/backup
sudo tail -f /var/log/borg-backup.log
sudo systemctl list-timers --all
# Проверим информацию о репозитории
borg info borg@192.168.11.160:/var/backup
```
![alt text](image.png)
```bash
#Проверяем когда следующий запуск:
root@client:~# sudo systemctl list-timers --all | grep borg
Thu 2025-08-21 19:46:37 MSK 12s left            Thu 2025-08-21 19:41:37 MSK 4min 47s ago borg-backup.timer              borg-backup.service

#Cписок таймеров можем посмотреть:
sudo systemctl list-timers --all

# Смотрим список файлов
borg list borg@192.168.11.160:/var/backup/::etc-2025-08-21_19:52:37
```
## Как мы видим, таймер и скрипт работают корректно:

1. **Таймер работает** - создает новые архивы каждые 5 минут
2. **Prune работает** - удаляет старые архивы согласно политике хранения
3. **Логи показывают** успешное выполнение операций

## Почему мы видим только 2 архива:

**Это правильное поведение**, т.к. Borg создает новый архив, а затем **удаляет старые** согласно политике:

- `--keep-daily 90` - хранить только последние 90 дней
- `--keep-monthly 12` - хранить только последние 12 месяцев  
- `--keep-yearly 1` - хранить только последний 1 год

Поскольку у нас архивы создаются каждые 5 минут, **prune удаляет все старые архивы**, оставляя только самые свежие согласно политике.

## Если в будущем понадобится сохранять больше архивов, то можем изменить политику:

```bash
# хранить последние 10 архивов
borg prune --keep-last 10 $REPO

# Или хранить архивы за последние 2 часа
borg prune --keep-within 2h $REPO
```

### Восстановление /etc:
```bash
# На client машине
# Останавливаем таймер
sudo systemctl stop borg-backup.timer

# Архивируем текущий /etc
sudo mv /etc /etc.old

# инициализируем репозиторий для восстановления
export BORG_PASSPHRASE='Otus1234'
export BORG_RSH='ssh -i /root/.ssh/borg_key -o StrictHostKeyChecking=no'

borg init --encryption=repokey borg@192.168.11.160:/var/backup/

# Список доступных бэкапов
root@client:~# borg list $REPO

test                                 Thu, 2025-08-21 00:31:00 [c223c4a52c5b068bb756a7383413e02165f62c9713291c7ed108fe6018bb077f]
etc-2025-08-21_19:52:37              Thu, 2025-08-21 19:52:38 [854c79288a3f0c7e2e3ea8ddf5aff39c4ed0c47e12b13d3c1085ee982c6a5f7a]

# # Восстанавливаем весь каталог /etc из последнего бэкапа etc-2025-08-21_19:52:37
borg extract borg@192.168.11.160:/var/backup/::etc-2025-08-21_19:52:37

# Проверяем восстановление
ls -la /etc/
# Проверяем критичные файлы
cat /etc/passwd
cat /etc/group
cat /etc/hostname
```
![alt text](image-1.png)

![alt text](image-2.png)

```bash
# Удаляем старый etc.old
sudo rm -rf /etc.old
```

## 6. Логирование

Логи будут доступны в:
- `/var/log/borg-backup.log` - детальные логи скрипта
- `journalctl -u borg-backup.service` - системные логи службы
- `logger` сообщения с тегом `borg-backup`

## Возможные проблемы
Если при попытке создать backup появляется ошибка "Доступ запрещен", хотя все ssh ключи cозданы ,прокинуты или скопированы руками, учетные записи и права на каталоги созданы ,то поможет (Ubuntu 22.04):

Проблема  В файле `/etc/ssh/sshd_config` на backup сервере:

1. **`PasswordAuthentication no`** - аутентификация по паролю отключена
2. **`#PubkeyAuthentication yes`** - аутентификация по ключу закомментирована (по умолчанию yes)
3. **`#PermitRootLogin prohibit-password`** - root доступ только по ключу

Но ключ не работает, исправим:

## Включаем аутентификацию по паролю временно:

```bash
# На backup сервере
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```
## Теперь копируем ключ еще раз:

```bash
# На client машине
ssh-copy-id -i /root/.ssh/borg_key.pub borg@192.168.11.160

# Введите пароль пользователя borg (Otus1234) когда запросит
```

##  Проверяем подключение по ключу:

```bash
ssh -i /root/.ssh/borg_key borg@192.168.11.160 "hostname"
```

##  Отключаем аутентификацию по паролю обратно:

```bash
# На backup сервере
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

##  Инициализируем Borg репозиторий:

```bash
# На client машине
export BORG_PASSPHRASE='Otus1234'
export BORG_RSH='ssh -i /root/.ssh/borg_key -o StrictHostKeyChecking=no'

borg init --encryption=repokey borg@192.168.11.160:/var/backup
```

##  Запускаем тестовый бэкап:

```bash
borg create --stats borg@192.168.11.160:/var/backup::test /etc/hosts
borg list borg@192.168.11.160:/var/backup
```

## Запускаем полный бэкап:

```bash
sudo /opt/backup/borg-backup.sh
```
Теперь SSH ключ должен работать! Проблема была в том, что аутентификация по паролю была отключена, а ключ еще не был properly настроен.


## Особенности реализации:

1. **Шифрование**: Используется repokey шифрование с паролем 'Otus1234'
2. **Политика хранения**: 
   - 90 daily backups (последние 3 месяца)
   - 12 monthly backups (год)
   - 1 yearly backup
3. **Автоматизация**: Systemd timer запускается каждые 5 минут
4. **Логирование**: Комплексное логирование с ротацией
5. **Безопасность**: SSH ключи для аутентификации

Это решение полностью соответствует требованиям задания и обеспечивает надежное резервное копирование с возможностью восстановления.