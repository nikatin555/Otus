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

# Установка и настройка AlmaLinux 10 и Ubuntu 22.04 с PAM ограничениями

## 1. Настройка PAM для ограничения доступа в выходные дни

### Для AlmaLinux 10:

```bash
# Установка необходимых пакетов
sudo dnf install -y pam pam_script

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
account    include      password-auth
password   include      password-auth
session    include      password-auth
session    include      postlogin
EOF

# Создание группы администраторов и добавление пользователей
sudo groupadd admingroup
sudo usermod -aG admingroup $(whoami)
```

### Для Ubuntu 22.04:

```bash
# Установка необходимых пакетов
sudo apt-get update
sudo apt-get install -y libpam-script

# Создание скрипта проверки дня недели (аналогично AlmaLinux)
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

# Создание группы администраторов и добавление пользователей
sudo groupadd admingroup
sudo usermod -aG admingroup $(whoami)
```

## 2. Настройка доступа к Docker для определенного пользователя

```bash
# Создание нового пользователя
sudo useradd -m dockeruser
sudo passwd dockeruser  # установите пароль

# Установка Docker (для обеих систем)
sudo curl -fsSL https://get.docker.com | sh

# Добавление пользователя в группу docker
sudo usermod -aG docker dockeruser

# Настройка прав на перезапуск Docker
sudo tee /etc/sudoers.d/dockeruser << 'EOF'
dockeruser ALL=(root) NOPASSWD: /bin/systemctl restart docker.service
EOF
```

## 3. Vagrantfile для развертывания

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Конфигурация для AlmaLinux 10
  config.vm.define "almalinux" do |almalinux|
    almalinux.vm.box = "generic/almalinux10"
    almalinux.vm.hostname = "almalinux-pam"
    almalinux.vm.network "private_network", ip: "192.168.0.10"
    
    almalinux.vm.provider "virtualbox" do |vb|
      vb.memory = "8192"
      vb.cpus = "2"
    end
    
    almalinux.vm.provision "shell", inline: <<-SHELL
      # Установка и настройка PAM (как в разделе 1 для AlmaLinux)
      dnf install -y pam pam_script curl
      
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
      
      # Группа администраторов
      groupadd admingroup
      usermod -aG admingroup vagrant
      
      # Настройка Docker (как в разделе 2)
      useradd -m dockeruser
      echo "dockeruser:password" | chpasswd
      curl -fsSL https://get.docker.com | sh
      usermod -aG docker dockeruser
      tee /etc/sudoers.d/dockeruser << 'EOF2'
      dockeruser ALL=(root) NOPASSWD: /bin/systemctl restart docker.service
      EOF2
    SHELL
  end

  # Конфигурация для Ubuntu 22.04
  config.vm.define "ubuntu" do |ubuntu|
    ubuntu.vm.box = "generic/ubuntu2204"
    ubuntu.vm.hostname = "ubuntu-pam"
    ubuntu.vm.network "private_network", ip: "192.168.0.20"
    
    ubuntu.vm.provider "virtualbox" do |vb|
      vb.memory = "8192"
      vb.cpus = "2"
    end
    
    ubuntu.vm.provision "shell", inline: <<-SHELL
      # Установка и настройка PAM (как в разделе 1 для Ubuntu)
      apt-get update
      apt-get install -y libpam-script curl
      
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
      
      # Группа администраторов
      groupadd admingroup
      usermod -aG admingroup vagrant
      
      # Настройка Docker (как в разделе 2)
      useradd -m dockeruser
      echo "dockeruser:password" | chpasswd
      curl -fsSL https://get.docker.com | sh
      usermod -aG docker dockeruser
      tee /etc/sudoers.d/dockeruser << 'EOF2'
      dockeruser ALL=(root) NOPASSWD: /bin/systemctl restart docker.service
      EOF2
    SHELL
  end
end
```

## Проверка работы

1. После развертывания VM попробуйте подключиться:
   - В выходные дни (суббота/воскресенье) доступ будет разрешен только пользователям из группы admingroup
   - В праздничные дни (которые указаны в скрипте) доступ будет разрешен всем
   - В рабочие дни доступ будет разрешен всем

2. Для проверки доступа к Docker:
   - Войдите как пользователь dockeruser
   - Проверьте доступ к Docker: `docker ps`
   - Проверьте перезапуск Docker: `sudo systemctl restart docker`

Для добавления пользователей в группу администраторов используйте команду:
```bash
sudo usermod -aG admingroup username
```

Для обновления списка праздничных дней отредактируйте файл `/usr/local/bin/check_weekday.sh` на каждой VM.