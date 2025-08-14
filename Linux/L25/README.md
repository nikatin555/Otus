# 25.  Основы сбора и хранения логов

## Домашнее задание

Настраиваем центральный сервер для сбора логов

**Цель:**

- научится проектировать централизованный сбор логов;
- рассмотреть особенности разных платформ для сбора логов.

Что нужно сделать?

   1. В Vagrant разворачиваем 2 виртуальные машины web и log
   2. на web настраиваем nginx
   3. на log настраиваем центральный лог сервер на любой системе на выбор:

    - journald;
    - rsyslog;
    - elk.

    4. настраиваем аудит, следящий за изменением конфигов nginx.


Все критичные логи с web должны собираться и локально и удаленно.

Все логи с nginx должны уходить на удаленный сервер (локально только критичные).

Логи аудита должны также уходить на удаленную систему.


Формат сдачи ДЗ - vagrant + ansible

Задание со звездочкой:
5. развернуть еще машину elk:

    - таким образом настроить 2 центральных лог системы elk и какую либо еще;
    - в elk должны уходить только логи nginx;
    - во вторую систему все остальное.


# Решение для сбора и хранения логов с использованием Vagrant

Полный `Vagrantfile`, который разворачивает инфраструктуру на Ubuntu 22.04:

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :
# Использование зеркала Vagrant репозиториев для РФ
ENV['VAGRANT_SERVER_URL'] = 'https://vagrant.elab.pro'

Vagrant.configure("2") do |config|
  # Общие настройки для всех машин
  config.vm.box = "ubuntu/jammy64"
   config.vm.provider "virtualbox" do |vb|
    vb.memory = 4096
    vb.cpus = 2
    vb.customize ["modifyvm", :id, "--pae", "on"]
    vb.customize ["modifyvm", :id, "--vram", "32"]
  end
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  SHELL

  # Машина web с nginx
  config.vm.define "web" do |web|
    web.vm.hostname = "web"
    web.vm.network "private_network", ip: "192.168.56.11"
    
    web.vm.provision "shell", inline: <<-SHELL
      # Установка nginx
      apt install -y nginx
      systemctl enable nginx
      systemctl start nginx
      
      # Настройка журналирования для nginx
      mkdir -p /var/log/nginx/remote
      chown www-data:adm /var/log/nginx/remote
      
      # Создаем конфиг для отправки логов
      cat <<EOF > /etc/rsyslog.d/60-nginx.conf
      module(load="imfile" PollingInterval="10")
      
      # Локальное хранение только критичных логов
      if \$syslogseverity <= 2 then {
        action(type="omfile" file="/var/log/nginx/critical.log")
      }
      
      # Отправка всех логов nginx на удаленный сервер
      input(type="imfile"
        File="/var/log/nginx/access.log"
        Tag="nginx-access"
        Severity="info"
        Facility="local6")
      
      input(type="imfile"
        File="/var/log/nginx/error.log"
        Tag="nginx-error"
        Severity="error"
        Facility="local6")
      
      local6.* @@192.168.56.12:514
      EOF
      
      # Настройка отправки критичных логов в journald
      cat <<EOF > /etc/systemd/journald.conf.d/remote.conf
      [Journal]
      ForwardToSyslog=yes
      MaxLevelSyslog=crit
      EOF
      
      # Установка и настройка аудита
      apt install -y auditd
      cat <<EOF > /etc/audit/rules.d/nginx.rules
      -w /etc/nginx/ -p wa -k nginx-config
      -w /etc/nginx/nginx.conf -p wa -k nginx-config
      -w /etc/nginx/sites-available/ -p wa -k nginx-config
      -w /etc/nginx/sites-enabled/ -p wa -k nginx-config
      EOF
      augenrules --load
      systemctl restart auditd
      
      # Настройка отправки логов аудита
      cat <<EOF > /etc/audit/plugins.d/syslog.conf
      active = yes
      direction = out
      path = builtin_syslog
      type = builtin 
      args = LOG_LOCAL6
      format = string
      EOF
      
      # Перенаправление логов аудита на удаленный сервер
      echo 'local6.* @@192.168.56.12:514' >> /etc/rsyslog.d/60-audit.conf
      
      # Перезапуск сервисов
      systemctl restart systemd-journald
      systemctl restart rsyslog
    SHELL
  end

  # Машина log с journald
  config.vm.define "log" do |log|
    log.vm.hostname = "log"
    log.vm.network "private_network", ip: "192.168.56.12"
    
    log.vm.provision "shell", inline: <<-SHELL
      # Настройка journald как центрального лог-сервера
      mkdir -p /var/log/journal
      chown root:systemd-journal /var/log/journal
      chmod 2755 /var/log/journal
      
      cat <<EOF > /etc/systemd/journald.conf
      [Journal]
      Storage=persistent
      ForwardToSyslog=no
      MaxLevelStore=debug
      MaxLevelSyslog=debug
      MaxLevelKMsg=notice
      MaxLevelConsole=info
      MaxLevelWall=emerg
      Compress=yes
      Seal=yes
      SplitMode=uid
      SyncIntervalSec=5m
      RateLimitInterval=30s
      RateLimitBurst=1000
      SystemMaxUse=1G
      SystemKeepFree=200M
      SystemMaxFileSize=100M
      RuntimeMaxUse=100M
      RuntimeKeepFree=50M
      RuntimeMaxFileSize=50M
      EOF
      
      # Настройка rsyslog для приема удаленных логов
      apt install -y rsyslog
      
      cat <<EOF > /etc/rsyslog.conf
      module(load="imuxsock") # provides support for local system logging
      module(load="imklog")   # provides kernel logging support
      module(load="imudp")
      module(load="imtcp")
      
      input(type="imudp" port="514")
      input(type="imtcp" port="514")
      
      \$template RemoteLogs,"/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log"
      *.* ?RemoteLogs
      & ~
      
      \$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
      \$IncludeConfig /etc/rsyslog.d/*.conf
      \$FileOwner syslog
      \$FileGroup adm
      \$FileCreateMode 0640
      \$DirCreateMode 0755
      \$Umask 0022
      EOF
      
      # Создаем директории для логов
      mkdir -p /var/log/remote
      chown syslog:adm /var/log/remote
      
      # Перезапуск сервисов
      systemctl restart systemd-journald
      systemctl restart rsyslog
    SHELL
  end

  # Дополнительная машина ELK (задание со звездочкой)
  config.vm.define "elk" do |elk|
    elk.vm.hostname = "elk"
    elk.vm.network "private_network", ip: "192.168.56.13"
    elk.vm.provider "virtualbox" do |vb|
      vb.memory = "6144"
      vb.cpus = 2
    end
    
    elk.vm.provision "shell", inline: <<-SHELL
      # Установка Docker для ELK
      curl -fsSL https://get.docker.com -o get-docker.sh
      sh get-docker.sh
      usermod -aG docker vagrant
      
      # Установка Docker Compose
      curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose
      
      # Создаем docker-compose.yml для ELK
      mkdir -p /opt/elk
      cat <<EOF > /opt/elk/docker-compose.yml
      version: '3'
      services:
        elasticsearch:
          image: docker.elastic.co/elasticsearch/elasticsearch:9.1.2
          container_name: elasticsearch
          environment:
            - discovery.type=single-node
            - bootstrap.memory_lock=true
            - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
          ulimits:
            memlock:
              soft: -1
              hard: -1
          volumes:
            - es_data:/usr/share/elasticsearch/data
          ports:
            - 9200:9200
          networks:
            - elk
          
        logstash:
          image: docker.elastic.co/logstash/logstash:9.1.2
          container_name: logstash
          volumes:
            - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
          ports:
            - 5044:5044
            - 5000:5000/tcp
            - 5000:5000/udp
          environment:
            LS_JAVA_OPTS: "-Xmx256m -Xms256m"
          networks:
            - elk
          depends_on:
            - elasticsearch
            
        kibana:
          image: docker.elastic.co/kibana/kibana:9.1.2
          container_name: kibana
          ports:
            - 5601:5601
          networks:
            - elk
          depends_on:
            - elasticsearch
            
      volumes:
        es_data:
          
      networks:
        elk:
          driver: bridge
      EOF
      
      # Конфиг Logstash для приема логов nginx
      cat <<EOF > /opt/elk/logstash.conf
      input {
        tcp {
          port => 5000
          type => "nginx"
        }
      }
      
      filter {
        if [type] == "nginx" {
          grok {
            match => { "message" => "%{COMBINEDAPACHELOG}" }
          }
          date {
            match => [ "timestamp", "dd/MMM/yyyy:HH:mm:ss Z" ]
            remove_field => [ "timestamp" ]
          }
        }
      }
      
      output {
        elasticsearch {
          hosts => ["elasticsearch:9200"]
          index => "nginx-%{+YYYY.MM.dd}"
        }
      }
      EOF
      
      # Запуск ELK
      cd /opt/elk && docker-compose up -d
      
      # На машине web нужно перенаправить логи nginx еще и на ELK
      # Это можно сделать вручную после развертывания:
      # На машине web выполнить:
      # echo 'local6.* @@192.168.56.13:5000' >> /etc/rsyslog.d/70-elastic.conf
      # systemctl restart rsyslog
    SHELL
  end
end
```

## Описание решения:

### 1. Виртуальные машины
- **web**: Устанавливает nginx и настраивает логирование
- **log**: Центральный лог-сервер на базе journald и rsyslog
- **elk** (задание со звездочкой): Стек ELK для анализа логов nginx

### 2. Настройка nginx на web-сервере
- Установлен и запущен nginx
- Настроено локальное хранение только критичных логов
- Все логи nginx отправляются на удаленный сервер log

### 3. Настройка аудита
- Установлен auditd
- Настроены правила аудита для отслеживания изменений конфигов nginx
- Логи аудита отправляются на удаленный сервер log

### 4. Центральный лог-сервер (log)
- Настроен journald для хранения логов
- Настроен rsyslog для приема удаленных логов
- Логи сохраняются в /var/log/remote с разделением по хостам и сервисам

### 5. ELK-стек (задание со звездочкой)
- Развернут Docker и Docker Compose
- Запущен стек ELK (Elasticsearch, Logstash, Kibana)
- Logstash настроен на прием логов nginx через TCP порт 5000
- Kibana доступна на порту 5601

После развертывания инфраструктуры:
- Логи nginx будут отправляться и на log-сервер, и в ELK
- Критичные логи будут храниться локально на web-сервере
- Логи аудита будут отправляться только на log-сервер

## Вариант 2: Оганизовать развертывание 3 машин через Vagrant с последующей конфигурацией через Ansible

### 1.  Создаём структуру проекта:
```text
project/
├── Vagrantfile          # Развертывание виртуальных машин
└── ansible/
    ├── inventory.ini    # Инвентарь Ansible
    ├── playbook.yml     # Основной плейбук
    ├── roles/
    │   ├── web/         # Роль для web-сервера
    │   ├── log/         # Роль для log-сервера
    │   └── elk/         # Роль для ELK
    └── group_vars/      # Переменные
        ├── all.yml
        ├── web.yml
        ├── log.yml
        └── elk.yml

project/
├── Vagrantfile          # Развертывание виртуальных машин
├── ansible/
│   ├── inventory.ini    # Инвентарь Ansible
│   ├── playbook.yml     # Основной плейбук
│   ├── roles/
│   │   ├── web/         # Роль для web-сервера
│   │   ├── log/         # Роль для log-сервера
│   │   └── elk/         # Роль для ELK
│   └── vars/           # Переменные
└── provisioning/       # Дополнительные скрипты
```
```bash
mkdir -p \
  ansible/roles/{web,log,elk}/{tasks,handlers,files,templates,vars,defaults,meta} \
  ansible/group_vars \
  ansible/host_vars \
  provisioning
  # Создаем основные файлы
touch \
  Vagrantfile \
  ansible/inventory.ini \
  ansible/playbook.yml \
  ansible/requirements.yml \
  ansible/group_vars/all.yml \
  ansible/group_vars/web.yml \
  ansible/group_vars/log.yml \
  ansible/group_vars/elk.yml \
  ansible/roles/web/tasks/main.yml \
  ansible/roles/log/tasks/main.yml \
  ansible/roles/elk/tasks/main.yml
  # Устанавливаем владельца 
  chown -R root:root /project

# Основные права для директорий
find /project -type d -exec chmod 755 {} \;

# Права для файлов
find /project -type f -exec chmod 644 {} \;

# Особые права для sensitive файлов
chmod 750 \
  ansible/group_vars \
  ansible/host_vars \
  provisioning

chmod 640 \
  ansible/group_vars/*.yml \
  ansible/host_vars/*.yml 2>/dev/null || true


```
### 2. Создадим Vagrantfile
```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_SERVER_URL'] = 'https://vagrant.elab.pro'

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  
  # Общие настройки для всех машин
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 4096
    vb.cpus = 2
    vb.customize ["modifyvm", :id, "--pae", "on"]
    vb.customize ["modifyvm", :id, "--vram", "32"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end

  # Машина web
  config.vm.define "web" do |web|
    web.vm.hostname = "web"
    web.vm.network "private_network", ip: "192.168.56.11"
    # Только базовая настройка, остальное через Ansible
    web.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y python3
    SHELL
  end

  # Машина log
  config.vm.define "log" do |log|
    log.vm.hostname = "log"
    log.vm.network "private_network", ip: "192.168.56.12"
    log.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y python3
    SHELL
  end

  # Машина elk
  config.vm.define "elk" do |elk|
    elk.vm.hostname = "elk"
    elk.vm.network "private_network", ip: "192.168.56.13"
    elk.vm.provider "virtualbox" do |vb|
      vb.memory = 6144
      vb.cpus = 4
    end
    elk.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y python3
    SHELL
  end
end

# Настройка провижининга Ansible для всех машин
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "ansible/playbook.yml"
    ansible.inventory_path = "ansible/inventory.ini"
    ansible.become = true
    ansible.limit = "all"
    ansible.verbose = "v"
    ansible.extra_vars = {
      ansible_ssh_user: 'vagrant',
      ansible_python_interpreter: "/usr/bin/python3"
    }
    
    # Опционально: отключить host key checking
    ansible.raw_arguments = [
      "--ssh-common-args='-o StrictHostKeyChecking=no'"
    ]
  end

  # Пост-провижининг (опционально)
  config.vm.post_up_message = <<-MESSAGE
  Система успешно развернута!
  Доступ к машинам:
    - web: 192.168.56.11
    - log: 192.168.56.12
    - elk: 192.168.56.13
  
  Для доступа используем:
    vagrant ssh web
    vagrant ssh log
    vagrant ssh elk
  
  Kibana доступна по адресу: http://192.168.56.13:5601
  MESSAGE
end
```

### 3. Ansible конфигурация

#### ansible/inventory.ini
```ini
[web]
192.168.56.11 ansible_user=vagrant ansible_ssh_private_key_file=.vagrant/machines/web/virtualbox/private_key

[log]
192.168.56.12 ansible_user=vagrant ansible_ssh_private_key_file=.vagrant/machines/log/virtualbox/private_key

[elk]
192.168.56.13 ansible_user=vagrant ansible_ssh_private_key_file=.vagrant/machines/elk/virtualbox/private_key

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

#### ansible/playbook.yml
```yaml
---
- name: Apply common configuration to all servers
  hosts: all
  become: true
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
      when: ansible_os_family == 'Debian'

    - name: Install basic packages
      package:
        name:
          - curl
          - wget
          - unzip
          - python3
        state: present

- name: Configure web servers
  hosts: web
  become: true
  roles:
    - web

- name: Configure log servers
  hosts: log
  become: true
  roles:
    - log

- name: Configure ELK stack
  hosts: elk
  become: true
  roles:
    - elk
```

#### Создадим базовые файлы ролей
Для каждой роли создадим основные задачи.

ansible/roles/web/tasks/main.yml

```yaml
---
- name: Install nginx
  apt:
    name: nginx
    state: present
    update_cache: yes

- name: Ensure nginx is running
  service:
    name: nginx
    state: started
    enabled: yes
```
ansible/roles/log/tasks/main.yml
```yaml
---
- name: Install rsyslog
  apt:
    name: rsyslog
    state: present

- name: Configure rsyslog to receive remote logs
  template:
    src: rsyslog.conf.j2
    dest: /etc/rsyslog.conf
    owner: root
    group: root
    mode: 0644
  notify: restart rsyslog

- name: Ensure rsyslog is running
  service:
    name: rsyslog
    state: started
    enabled: yes
  ```
  ansible/roles/elk/tasks/main.yml
```yaml
---
- name: Install Docker prerequisites
  apt:
    name:
      - apt-transport-https
      - ca-certificates
      - curl
      - software-properties-common
    state: present

- name: Add Docker GPG key
  apt_key:
    url: https://download.docker.com/linux/ubuntu/gpg
    state: present

- name: Add Docker repository
  apt_repository:
    repo: deb [arch=amd64] https://download.docker.com/linux/ubuntu jammy stable
    state: present

- name: Install Docker
  apt:
    name: docker-ce
    state: present
    update_cache: yes
```


### 4. Процесс работы

**Развертывание инфраструктуры**:
   ```bash
   vagrant up
   ```
   PS: на AlamaLinux 10 заметил, что с 1го раза не разворачивается все VM или все приложения, п.э. приходится vagrant запускать повторно (на Windows таких проблем нет):
   ```bash
   ==> web: Machine 'web' has a post `vagrant up` message. This is a message
==> web: from the creator of the Vagrantfile, and not from Vagrant itself:
==> web:
==> web:   Система успешно развернута!
==> web:   Доступ к машинам:
==> web:     - web: 192.168.56.11
==> web:     - log: 192.168.56.12
==> web:     - elk: 192.168.56.13
==> web:
==> web:   Для доступа используем:
==> web:     vagrant ssh web
==> web:     vagrant ssh log
==> web:     vagrant ssh elk
==> web:
==> web:   Kibana доступна по адресу: http://192.168.56.13:5601
==> web:

==> log: Machine 'log' has a post `vagrant up` message. This is a message
==> log: from the creator of the Vagrantfile, and not from Vagrant itself:
==> log:
==> log:   Система успешно развернута!
==> log:   Доступ к машинам:
==> log:     - web: 192.168.56.11
==> log:     - log: 192.168.56.12
==> log:     - elk: 192.168.56.13
==> log:
==> log:   Для доступа используем:
==> log:     vagrant ssh web
==> log:     vagrant ssh log
==> log:     vagrant ssh elk
==> log:
==> log:   Kibana доступна по адресу: http://192.168.56.13:5601
==> log:

==> elk: Machine 'elk' has a post `vagrant up` message. This is a message
==> elk: from the creator of the Vagrantfile, and not from Vagrant itself:
==> elk:
==> elk:   Система успешно развернута!
==> elk:   Доступ к машинам:
==> elk:     - web: 192.168.56.11
==> elk:     - log: 192.168.56.12
==> elk:     - elk: 192.168.56.13
==> elk:
==> elk:   Для доступа используем:
==> elk:     vagrant ssh web
==> elk:     vagrant ssh log
==> elk:     vagrant ssh elk
==> elk:
==> elk:   Kibana доступна по адресу: http://192.168.56.13:5601
==> elk:
```

Если проблема с установокой приложений остаётся, то можно запустить конфигурацию через Ansible:
   ```bash
   cd ansible
   ansible-playbook -i inventory.ini playbook.yml
   ```

### 5. Проверка работы

Для проверки можно использовать ad-hoc команды Ansible:
```bash
# Проверить сервисы на web-сервере
ansible web -i inventory.ini -m shell -a "systemctl status nginx auditd"

# Проверить логи на log-сервере
ansible log -i inventory.ini -m shell -a "ls -la /var/log/remote/"

# Проверить контейнеры ELK
ansible elk -i inventory.ini -m shell -a "docker ps"
```

### Преимущества такого подхода:
1. Четкое разделение инфраструктуры и конфигурации
2. Возможность повторного использования ролей Ansible
3. Более гибкое управление конфигурацией
4. Идемпотентность - можно запускать плейбук многократно

Для более сложной настройки можно добавить переменные в `group_vars/` и `host_vars/`, а также использовать теги для выборочного выполнения задач.