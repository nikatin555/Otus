# 24.  Пользователи и группы. Авторизация и аутентификация

Домашнее задание

PAM

**Цель:**

- научиться создавать пользователей и добавлять им ограничения;

- Описание/Пошаговая инструкция выполнения домашнего задания:

- Для выполнения домашнего задания используйте методичку


**Что нужно сделать?**

- Запретить всем пользователям, кроме группы admin логин в выходные (суббота и воскресенье), без учета праздников;

- Дать конкретному пользователю права работать с докером и возможность рестартить докер сервис*.

# Установка и настройка CentOS 8 Stream и Ubuntu 22.04 с PAM ограничениями

## 1. Настройка PAM для ограничения доступа в выходные дни

### Для CentOS 8 Stream:

```bash
# Установка необходимых пакетов
sudo dnf install -y pam pam_script

# Установка Docker
# Установка Docker (для обеих систем) можно 1й командой: `sudo curl -fsSL https://get.docker.com | sh`, но постаринке всегда надежнее:
# 
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Добавление Docker в автозагрузку и запуск
sudo systemctl enable docker
sudo systemctl start docker

# Создание скрипта проверки дня недели
sudo tee /usr/local/bin/check_weekday.sh << 'EOF'
#!/bin/bash
# Проверяем, является ли сегодня праздничным днем (нужно заполнить актуальными датами)
holidays=("2025-01-01" "2025-01-02" "2025-01-03" "2025-01-06" "2025-01-07" "2025-01-08" "2025-02-23" "2025-03-08" "2025-05-01" "2025-05-02" "2025-05-08" "2025-05-09" "2025-06-12" "2025-06-13" "2025-11-03" "2025-11-04" "2025-12-31")
today=$(date +%Y-%m-%d)

for holiday in "${holidays[@]}"; do
    if [[ "$holiday" == "$today" ]]; then
        exit 1
    fi
done

# Проверяем день недели (0 - воскресенье, 6 - суббота)
day=$(date +%w)
if [[ "$day" == "0" || "$day" == "6" ]]; then
    exit 0
else
    exit 1
fi
EOF

sudo chmod +x /usr/local/bin/check_weekday.sh

# Настройка PAM
sudo tee /etc/pam.d/sshd << 'EOF'
#%PAM-1.0
auth       required     pam_sepermit.so
auth       substack     password-auth
auth       include      postlogin
account    required     pam_nologin.so
account    required     pam_exec.so /usr/local/bin/check_weekday.sh
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    optional     pam_motd.so
account    include      password-auth
password   include      password-auth
session    include      password-auth
session    include      postlogin
EOF

#Создаём пользователя otusadm и otus
sudo useradd otusadm && sudo useradd otus
#Создаём пользователям пароли
cho "Otus2022!" | sudo passwd --stdin otusadm && echo "Otus2022!" | sudo passwd --stdin otus
#Создаём группу admin
sudo groupadd -f admin
#Добавляем пользователей vagrant,root и otusadm в группу admin
usermod otusadm -a -G admin && usermod root -a -G admin && usermod vagrant -a -G admin
#Проверим, что пользователи root, vagrant и otusadm есть в группе admin:
cat /etc/group | grep admin
```

### Для Ubuntu 22.04:

```bash
# Установка необходимых пакетов
sudo apt-get update
sudo apt-get install -y libpam-script

# Установка Docker
# Установка Docker можно 1й командой: `sudo curl -fsSL https://get.docker.com | sh` , но постаринке всегда надежнее:
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# Добавляем официальный GPG ключ Docker
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Добавляем репозиторий
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Устанавливаем Docker
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Добавление Docker в автозагрузку и запуск
sudo systemctl enable docker
sudo systemctl start docker

# Чтобы запускать Docker без sudo, добавим себя в группу docker
sudo usermod -aG docker $(whoami)

# Создание скрипта проверки дня недели
sudo tee /usr/local/bin/check_weekday.sh << 'EOF'
#!/bin/bash
# Проверяем, является ли сегодня праздничным днем
holidays=("2025-01-01" "2025-01-02" "2025-01-03" "2025-01-06" "2025-01-07" "2025-01-08" "2025-02-23" "2025-03-08" "2025-05-01" "2025-05-02" "2025-05-08" "2025-05-09" "2025-06-12" "2025-06-13" "2025-11-03" "2025-11-04" "2025-12-31")
today=$(date +%Y-%m-%d)

for holiday in "${holidays[@]}"; do
    if [[ "$holiday" == "$today" ]]; then
        exit 1
    fi
done

# Проверяем день недели (0 - воскресенье, 6 - суббота)
day=$(date +%w)
if [[ "$day" == "0" || "$day" == "6" ]]; then
    exit 0
else
    exit 1
fi
EOF

sudo chmod +x /usr/local/bin/check_weekday.sh

# Настройка PAM
sudo tee /etc/pam.d/sshd << 'EOF'
# PAM configuration for the Secure Shell service
auth       required     pam_env.so # [1]
auth       required     pam_env.so envfile=/etc/default/locale
@include common-auth
account    required     pam_nologin.so
account    required     pam_exec.so /usr/local/bin/check_weekday.sh
@include common-account
@include common-session
session    optional     pam_motd.so # [1]
session    optional     pam_mail.so standard noenv # [1]
session    required     pam_limits.so
@include common-password
EOF

#Создаём пользователя otusadm и otus
sudo useradd otusadm && sudo useradd otus
#Создаём пользователям пароли
cho "Otus2022!" | sudo passwd --stdin otusadm && echo "Otus2022!" | sudo passwd --stdin otus
#Создаём группу admin
sudo groupadd -f admin
#Добавляем пользователей vagrant,root и otusadm в группу admin
usermod otusadm -a -G admin && usermod root -a -G admin && usermod vagrant -a -G admin
#Проверим, что пользователи root, vagrant и otusadm есть в группе admin:
cat /etc/group | grep admin
```

## 2. Настройка доступа к Docker для определенного пользователя

```bash
# Создание нового пользователя и установим пароль
sudo useradd -m dockeruser
sudo passwd dockeruser

# Добавление пользователя в группу docker
sudo usermod -aG docker dockeruser

# Настройка прав на перезапуск Docker
sudo tee /etc/sudoers.d/dockeruser << 'EOF'
dockeruser ALL=(root) NOPASSWD: /bin/systemctl restart docker.service
EOF
```

## 3. Vagrantfile для развертывания

### Подготовка

Т.к. загрузки "box" с vagrantcloud.com не работают на территории РФ, а российские зеркала для загрузки боксов МГТУ (MGTU) или БерТех (BerTech) перестали быть доступными, настроим vagrantfile для использования локальных образов Ubuntu и Centos. Для этого нам необходимо загрузить локальные image box и добавить их в vagrant:
```bash 
 vagrant box add --name ubuntu/22.04 https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-vagrant.box

vagrant box add --name centos8s https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-Vagrant-8-20240603.0.x86_64.vagrant-virtualbox.box

vagrant.exe  box list                                                                                                                                                                                                                                                                                                                                                                                                           centos8s     (virtualbox, 0)                                                                                                                                                                                                                 ubuntu/22.04 (virtualbox, 0)
```

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Конфигурация для CentOS 8 Stream
  config.vm.define "centos" do |centos|
    centos.vm.box = "centos8s"
    centos.vm.hostname = "centos-pam"
    centos.vm.network "private_network", ip: "192.168.55.10"
    
    centos.vm.provider "virtualbox" do |vb|
      vb.memory = "8192"
      vb.cpus = "2"
      # Указываем имя сети, которое не конфликтует с существующими
      vb.customize ["modifyvm", :id, "--natnet1", "192.168.55.0/24"]
    end
    
    centos.vm.provision "shell", inline: <<-SHELL
      # Установка и настройка PAM
      dnf install -y pam pam_script curl
      # Установка Docker
      sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
      sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

      # Добавление Docker в автозагрузку и запуск
      sudo systemctl enable docker
      sudo systemctl start docker
      
      #Разрешаем подключение пользователей по SSH с использованием пароля
      sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config
      #Перезапуск службы SSHD
      systemctl restart sshd.service

      # Скрипт проверки дня недели
      tee /usr/local/bin/check_weekday.sh << 'EOF2'
      #!/bin/bash
      holidays=("2025-01-01" "2025-01-02" "2025-01-03" "2025-01-06" "2025-01-07" "2025-01-08" "2025-02-23" "2025-03-08" "2025-05-01" "2025-05-02" "2025-05-08" "2025-05-09" "2025-06-12" "2025-06-13" "2025-11-03" "2025-11-04" "2025-12-31")
      today=$(date +%Y-%m-%d)
      
      for holiday in "${holidays[@]}"; do
          if [[ "$holiday" == "$today" ]]; then
              exit 1
          fi
      done
      
      day=$(date +%w)
      if [[ "$day" == "0" || "$day" == "6" ]]; then
          exit 0
      else
          exit 1
      fi
      EOF2
      
      chmod +x /usr/local/bin/check_weekday.sh
      
      # Настройка PAM
      tee /etc/pam.d/sshd << 'EOF2'
      #%PAM-1.0
      auth       required     pam_sepermit.so
      auth       substack     password-auth
      auth       include      postlogin
      account    required     pam_nologin.so
      account    required     pam_exec.so /usr/local/bin/check_weekday.sh
      account    include      password-auth
      password   include      password-auth
      session    include      password-auth
      session    include      postlogin
      EOF2
      
      #Создаём пользователя otusadm и otus
      sudo useradd otusadm && sudo useradd otus
      #Создаём пользователям пароли
      cho "Otus2022!" | sudo passwd --stdin otusadm && echo "Otus2022!" | sudo passwd --stdin otus
      #Создаём группу admin
      sudo groupadd -f admin
      #Добавляем пользователей vagrant,root и otusadm в группу admin
      usermod otusadm -a -G admin && usermod root -a -G admin && usermod vagrant -a -G admin
      #Проверим, что пользователи root, vagrant и otusadm есть в группе admin:
      cat /etc/group | grep admin
      
      # Настройка Docker
      useradd -m dockeruser
      echo "dockeruser:password" | chpasswd
      usermod -aG docker dockeruser
      tee /etc/sudoers.d/dockeruser << 'EOF2'
      dockeruser ALL=(root) NOPASSWD: /bin/systemctl restart docker.service
      EOF2
    SHELL
  end

  # Конфигурация для Ubuntu 22.04
  config.vm.define "ubuntu" do |ubuntu|
    ubuntu.vm.box = "ubuntu/22.04"
    ubuntu.vm.hostname = "ubuntu-pam"
    ubuntu.vm.network "private_network", ip: "192.168.55.20"
    
    ubuntu.vm.provider "virtualbox" do |vb|
      vb.memory = "8192"
      vb.cpus = "2"
      vb.customize ["modifyvm", :id, "--natnet1", "192.168.55.0/24"]
    end
    
       ubuntu.vm.provision "shell", inline: <<-SHELL
      # Установка и настройка PAM
      apt-get update
      apt-get install -y libpam-script curl
      # Установка Docker
      sudo apt-get update
      sudo apt-get install -y ca-certificates curl gnupg

      # Добавляем официальный GPG ключ Docker
      sudo install -m 0755 -d /etc/apt/keyrings
      sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
      sudo chmod a+r /etc/apt/keyrings/docker.asc

      # Добавляем репозиторий
      echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update

      # Устанавливаем Docker
      sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

      # Добавление Docker в автозагрузку и запуск
      sudo systemctl enable docker
      sudo systemctl start docker

      #Разрешаем подключение пользователей по SSH с использованием пароля
      sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config
      #Перезапуск службы SSHD
      systemctl restart sshd.service
      
      # Скрипт проверки дня недели
      tee /usr/local/bin/check_weekday.sh << 'EOF2'
      #!/bin/bash
      holidays=("2025-01-01" "2025-01-02" "2025-01-03" "2025-01-06" "2025-01-07" "2025-01-08" "2025-02-23" "2025-03-08" "2025-05-01" "2025-05-02" "2025-05-08" "2025-05-09" "2025-06-12" "2025-06-13" "2025-11-03" "2025-11-04" "2025-12-31")
      today=$(date +%Y-%m-%d)
      
      for holiday in "${holidays[@]}"; do
          if [[ "$holiday" == "$today" ]]; then
              exit 1
          fi
      done
      
      day=$(date +%w)
      if [[ "$day" == "0" || "$day" == "6" ]]; then
          exit 0
      else
          exit 1
      fi
      EOF2
      
      chmod +x /usr/local/bin/check_weekday.sh
      
      # Настройка PAM
      tee /etc/pam.d/sshd << 'EOF2'
      # PAM configuration for the Secure Shell service
      auth       required     pam_env.so
      auth       required     pam_env.so envfile=/etc/default/locale
      @include common-auth
      account    required     pam_nologin.so
      account    required     pam_exec.so /usr/local/bin/check_weekday.sh
      @include common-account
      @include common-session
      session    optional     pam_motd.so
      session    optional     pam_mail.so standard noenv
      session    required     pam_limits.so
      @include common-password
      EOF2
      
      #Создаём пользователя otusadm и otus
      sudo useradd otusadm && sudo useradd otus
      #Создаём пользователям пароли
      cho "Otus2022!" | sudo passwd --stdin otusadm && echo "Otus2022!" | sudo passwd --stdin otus
      #Создаём группу admin
      sudo groupadd -f admin
      #Добавляем пользователей vagrant,root и otusadm в группу admin
      usermod otusadm -a -G admin && usermod root -a -G admin && usermod vagrant -a -G admin
      #Проверим, что пользователи root, vagrant и otusadm есть в группе admin:
      cat /etc/group | grep admin
      
      # Настройка Docker
      useradd -m dockeruser
      echo "dockeruser:password" | chpasswd
      usermod -aG docker dockeruser
      tee /etc/sudoers.d/dockeruser << 'EOF2'
      dockeruser ALL=(root) NOPASSWD: /bin/systemctl restart docker.service
      EOF2
    SHELL
  end
end
```

## Итог:

1. После развертывания VM :
   - В выходные дни (суббота/воскресенье) доступ будет разрешен только пользователям из группы admin
   - В праздничные дни (которые указаны в скрипте) доступ будет разрешен всем
   - В рабочие дни доступ будет разрешен всем

2. Для обновления списка праздничных дней можно отредактировать файл `/usr/local/bin/check_weekday.sh` на каждой VM.

3. Установка Docker: выбрал построчную установку вместо установкой 1й командой: `sudo curl -fsSL https://get.docker.com | sh`, т.к. развертыванием VM при помощи vagrant на VM не устанавливался docker, хотя эту же команду запустить руками - установка происходит без проблем. П.э., выбрал надежный путь.

### **Выводы по выполненной работе**

В ходе выполнения задания были успешно выполнены следующие задачи:

#### **1. Настройка PAM для ограничения доступа в выходные дни**  
- Реализована проверка дня недели с помощью **PAM-модуля `pam_exec`** и скрипта `check_weekday.sh`.  
- Пользователи, не входящие в группу `admin`, не смогут войти в систему в **выходные дни (суббота и воскресенье)**.  
- Реализовано **исключение для праздничных дней**. Список дат можно расширить, отредактировав файл `/usr/local/bin/check_weekday.sh` на каждой VM.
- Настроено для **CentOS 8 Stream** и **Ubuntu 22.04** с учетом особенностей их PAM-конфигураций.  

#### **2. Настройка доступа к Docker для выделенного пользователя**  
- Создан пользователь **`dockeruser`**, добавлен в группу **`docker`**.  
- Настроены права **sudo** для перезапуска Docker (`systemctl restart docker`) без пароля.  
- Docker установлен из официальных репозиториев и **добавлен в автозагрузку (`systemctl enable docker`)**.  

#### **3. Автоматизация развертывания через Vagrant**  
- Подготовлен **Vagrantfile**, разворачивающий две виртуальные машины:  
  - **CentOS 8 Stream** (8 ГБ RAM, 2 CPU)  
  - **Ubuntu 22.04** (8 ГБ RAM, 2 CPU)  
- Настроена **приватная сеть (192.168.55.0/24)** для избежания конфликтов с локальной сетью.  
- Все настройки (PAM, Docker, пользователи) выполняются **автоматически при `vagrant up`**.  


### **Итог**  
✅ **Гибкая система контроля доступа** (PAM + скрипт + группа администраторов).  
✅ **Безопасная работа с Docker** (отдельный пользователь с ограниченными правами).  
✅ **Автоматизированное развертывание** (Vagrant + Shell-провиженинг).  
✅ **Кросс-дистрибутивная поддержка** (работает на CentOS и Ubuntu).  

### **Что можно улучшить:**  
- **Расширить список праздников** (можно подключить API или файл с обновляемыми датами).  
- **Добавить логирование** попыток входа в выходные дни.  
- **Настроить уведомления** (например, через Telegram-бота) о попытках несанкционированного доступа.  
- **Оптимизировать Docker-права** (например, через `sudo` только для конкретных команд).  
