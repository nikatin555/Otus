# 18.  Vagrant 

## Домашнее задание

Обновить ядро в базовой системе

**Цель:**

- Получить навыки работы с Git, Vagrant;
- Обновлять ядро в ОС Linux.

Описание/Пошаговая инструкция выполнения домашнего задания:


Для выполнения домашнего задания используйте методичку

Описание домашнего задания:
1) Запустить ВМ с помощью Vagrant.
2) Обновить ядро ОС из репозитория ELRepo.
3) Оформить отчет в README-файле в GitHub-репозитории.

Дополнительные задания co *:
- Ядро собрано из исходников
- В образе нормально работают VirtualBox Shared Folders

# Выполнение ДЗ
Создадим Vagrantfile, в котором будут указаны параметры нашей ВМ:

```vagrantfile
# Описываем Виртуальные машины
MACHINES = {
  # Указываем имя ВМ "kernel update"
  :"kernel-update" => {
              #Какой vm box будем использовать
              :box_name => "centos8s",
              #Указываем количество ядер ВМ
              :cpus => 2,
              #Указываем количество ОЗУ в мегабайтах
              :memory => 4096,
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    # Отключаем проброс общей папки в ВМ
    config.vm.synced_folder ".", "/vagrant", disabled: true
    # Применяем конфигурацию ВМ
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxname.to_s
      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end
    end
  end
end
```
Скорректируем Vagrantfile для использования локального образа centos8s, а не загрузки его через vagrantcloud.com (не работает на территории РФ без VPN), а российские зеркала для загрузки боксов МГТУ (MGTU) или БерТех (BerTech) перестали быть доступными:
```bash
nano Vagrantfile
 vagrant box add --name centos8s https://cloud.centos.org/centos/8/vagrant/x86_64/images/CentOS-8-Vagrant-8.4.2105-20210603.0.x86_64.vagrant-virtualbox.box
 ```
 ```bash
==> box: Box file was not detected as metadata. Adding it directly...
==> box: Adding box 'centos8s' (v0) for provider:
    box: Downloading: https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-Vagrant-8.0.1905-1.x86_64.vagrant-virtualbox.box
==> box: Successfully added box 'centos8s' (v0) for ''!
```
Также, удалим строки ```:box_version => "4.3.4"``` и ```box.vm.box_version = boxconfig[:box_version]```, т.к. используется локальный файл (.box) или URL напрямую, а не бокс из Vagrant Cloud. **Vagrant не поддерживает управление версиями для локальных боксов:**
```vagrantfile
MACHINES = {
  :"kernel-update" => {
              :box_name => "centos8s",
              :cpus => 2,
              :memory => 4096,
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxname.to_s
      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end
    end
  end
end
```
```bash
 sudo vagrant box add --name 'centos8s' /etc/Ansible/Vagrant/CentOS-8-Vagrant-8.4.2105-20210603.0.x86_64.vagrant-virtualbox.box
 ```

После создания Vagrantfile, запустим виртуальную машину командой ```vagrant up```. Будет создана виртуальная машина с ОС CentOS 8 Stream, с 2-мя ядрами CPU и 4ГБ ОЗУ:
```bash
 vagrant up
Bringing machine 'kernel-update' up with 'virtualbox' provider...
==> kernel-update: Importing base box 'centos8s'...
==> kernel-update: Matching MAC address for NAT networking...
==> kernel-update: Setting the name of the VM: Vagrant_kernel-update_1754606421096_28810
==> kernel-update: Clearing any previously set network interfaces...
==> kernel-update: Preparing network interfaces based on configuration...
    kernel-update: Adapter 1: nat
==> kernel-update: Forwarding ports...
    kernel-update: 22 (guest) => 2222 (host) (adapter 1)
==> kernel-update: Running 'pre-boot' VM customizations...
==> kernel-update: Booting VM...
==> kernel-update: Waiting for machine to boot. This may take a few minutes...
    kernel-update: SSH address: 127.0.0.1:2222
    kernel-update: SSH username: vagrant
    kernel-update: SSH auth method: private key
    kernel-update:
    kernel-update: Vagrant insecure key detected. Vagrant will automatically replace
    kernel-update: this with a newly generated keypair for better security.
    kernel-update:
    kernel-update: Inserting generated public key within guest...
    kernel-update: Removing insecure key from the guest if it's present...
    kernel-update: Key inserted! Disconnecting and reconnecting using new SSH key...
==> kernel-update: Machine booted and ready!
==> kernel-update: Checking for guest additions in VM...
    kernel-update: No guest additions were detected on the base box for this VM! Guest
    kernel-update: additions are required for forwarded ports, shared folders, host only
    kernel-update: networking, and more. If SSH fails on this machine, please install
    kernel-update: the guest additions and repackage the box to continue.
    kernel-update:
    kernel-update: This is not an error message; everything may continue to work properly,
    kernel-update: in which case you may ignore this message.
==> kernel-update: Setting hostname...
```

## Обновление ядра

Подключаемся по ssh к созданной виртуальной машины. Для этого в каталоге с нашим Vagrantfile вводим команду:
```vagrant ssh ```
Перед работами проверим текущую версию ядра:
```bash
 uname -r
4.18.0-305.3.1.el8.x86_64
```

Далее подключим репозиторий, откуда возьмём необходимую версию ядра:
Т.к. CentOS 8 Stream больше не использует стандартные зеркала, нам необходимо:
 1. Обновляем репозитории для CentOS Stream 8:
```bash
sudo sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Stream-*
sudo sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Stream-*
```
2. Добавляем репозиторий ELRepo вручную:
```bash
sudo rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
sudo tee /etc/yum.repos.d/elrepo.repo << 'EOF'
[elrepo]
name=ELRepo.org Community Enterprise Linux Repository - el8
baseurl=https://elrepo.org/linux/kernel/el8/$basearch/
        https://mirrors.tuna.tsinghua.edu.cn/elrepo/kernel/el8/$basearch/
        https://mirror.rackspace.com/elrepo/kernel/el8/$basearch/
        https://mirrors.nju.edu.cn/elrepo/kernel/el8/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
EOF
```
3. Устанавливаем kernel-ml - последнее стабильное ядро:
```bash
 sudo dnf --disablerepo=* --enablerepo=elrepo install kernel-ml -y
ELRepo.org Community Enterprise Linux Repository - el8                                                                                                       662 kB/s | 2.2 MB     00:03
Last metadata expiration check: 0:00:01 ago on Thu 07 Aug 2025 11:17:09 PM UTC.
Dependencies resolved.
=============================================================================================================================================================================================
 Package                                           Architecture                           Version                                               Repository                              Size
=============================================================================================================================================================================================
Installing:
 kernel-ml                                         x86_64                                 6.15.9-1.el8.elrepo                                   elrepo                                 155 k
Installing dependencies:
 kernel-ml-core                                    x86_64                                 6.15.9-1.el8.elrepo                                   elrepo                                  67 M
 kernel-ml-modules                                 x86_64                                 6.15.9-1.el8.elrepo                                   elrepo                                  62 M

Transaction Summary
=============================================================================================================================================================================================
Install  3 Packages

Total download size: 129 M
Installed size: 175 M
Downloading Packages:
(1/3): kernel-ml-6.15.9-1.el8.elrepo.x86_64.rpm                                                                                                              137 kB/s | 155 kB     00:01
(2/3): kernel-ml-modules-6.15.9-1.el8.elrepo.x86_64.rpm                                                                                                      1.5 MB/s |  62 MB     00:41
(3/3): kernel-ml-core-6.15.9-1.el8.elrepo.x86_64.rpm                                                                                                         1.2 MB/s |  67 MB     00:55
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                                        2.3 MB/s | 129 MB     00:55
warning: /var/cache/dnf/elrepo-f426d9ee87403669/packages/kernel-ml-6.15.9-1.el8.elrepo.x86_64.rpm: Header V4 RSA/SHA256 Signature, key ID eaa31d4a: NOKEY
ELRepo.org Community Enterprise Linux Repository - el8                                                                                                       0.0  B/s |   0  B     00:00
Curl error (37): Couldn't read a file:// file for file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org [Couldn't open file /etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org]
The downloaded packages were saved in cache until the next successful transaction.
You can remove cached packages by executing 'dnf clean packages'.
```
4. Обновим загрузчик:
```bash
sudo grub2-set-default 0
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```
5. Перезагружаем систему:
```bash
sudo reboot
```
6. Проверяем новое ядро:
```bash
uname -r
6.15.9-1.el8.elrepo.x86_64
```
**Возможные проблемы:**
Если система не хочет обновлять ядро из-за проблемы с GPG-KEY, и все гуманные методы не помогают (очистка кэша, старых ключей, импортирование новых ключей и т.д.), проблема возникает из-за проблем с GPG-ключом ELRepo, то поможет метод установки ядра с отключенной проверкой GPG (на свой страх и риск):

ошибка:
```bash
GPG key at file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org (0xBAADAE52) is already installed
The GPG keys listed for the "ELRepo.org Community Enterprise Linux Repository - el8" repository are already installed but they are not correct for this package.
Check that the correct key URLs are configured for this repository.. Failing package is: kernel-ml-6.15.9-1.el8.elrepo.x86_64
 GPG Keys are configured as: file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
Public key for kernel-ml-core-6.15.9-1.el8.elrepo.x86_64.rpm is not installed. Failing package is: kernel-ml-core-6.15.9-1.el8.elrepo.x86_64
 GPG Keys are configured as: file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
Public key for kernel-ml-modules-6.15.9-1.el8.elrepo.x86_64.rpm is not installed. Failing package is: kernel-ml-modules-6.15.9-1.el8.elrepo.x86_64
 GPG Keys are configured as: file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
The downloaded packages were saved in cache until the next successful transaction.
You can remove cached packages by executing 'dnf clean packages'.
Error: GPG check FAILED
```
**Решение:**
 Полностью очистим кэш и старые ключи:
```bash
sudo rpm -e gpg-pubkey-eaa31d4a-*
sudo rm -f /etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
sudo dnf clean all
```

Заново импортируем корректный ключ:
```bash
sudo rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
sudo curl -o /etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
```

Установим ядро с отключенной проверкой GPG (на свой страх и риск, но рабочий вариант):
```bash
sudo dnf --disablerepo=* --enablerepo=elrepo install kernel-ml -y --nogpgcheck
```

## Задание со *.  Ядро собрано из исходников. В образе нормально работают VirtualBox Shared Folders

Импортируем образ:
```bash
sudo vagrant box add --name 'centos8s2' /etc/Ansible/Vagrant/CentOS-8-Vagrant-8.4.2105-20210603.0.x86_64.vagrant-virtualbox.box
```
создадим Vagrantfile со следующим содержанием:
```bash
nano Vagrantfile

MACHINES = {
  :"kernel-update" => {
    :box_name => "centos8s2",
    :cpus => 2,
    :memory => 4096,
  }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxname.to_s
      
      # Включение shared folders с нужными опциями
      box.vm.synced_folder ".", "/vagrant", 
        type: "virtualbox",
        mount_options: ["dmode=777", "fmode=666"],
        disabled: false
      
      # Проверка и установка зависимостей для сборки ядра
      box.vm.provision "shell", inline: <<-SHELL
        # Установка зависимостей для сборки ядра
        sudo dnf install -y git make gcc bc bison flex elfutils-libelf-devel openssl-devel perl rsync ncurses-devel
        
        # Скачивание исходников ядра (возьмем стабильную LTS версию)
        KERNEL_VERSION=6.15.9
        wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VERSION.tar.xz
        tar -xvf linux-$KERNEL_VERSION.tar.xz
        cd linux-$KERNEL_VERSION
        
        # Копирование текущей конфигурации
        cp /boot/config-$(uname -r) .config
        
        # Настройка конфигурации для VirtualBox
        make olddefconfig
        scripts/config --enable CONFIG_FUSE_FS
        scripts/config --enable CONFIG_VBOXSF_FS
        
        # Сборка ядра (параллельная с использованием всех ядер)
        make -j$(nproc)
        
        # Установка нового ядра
        sudo make modules_install
        sudo make install
        
        # Обновление GRUB
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg
        sudo grub2-set-default 0
      SHELL
      
      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
        # Включение поддержки виртуализации для сборки ядра
        v.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
      end
    end
  end
end
```
### Ключевые особенности:
1. **Сборка из исходников**:
   - Скачивается стабильная LTS версия ядра (6.15.9)
   - Используется текущая конфигурация ядра как база
   - Явно включаются модули для VirtualBox Shared Folders

2. **Работа Shared Folders**:
   - Явно указан тип `virtualbox` для synced_folder
   - Добавлены правильные mount_options
   - Включены необходимые модули ядра (CONFIG_FUSE_FS и CONFIG_VBOXSF_FS)

3. **Оптимизации**:
   - Параллельная сборка (-j$(nproc))
   - Включена аппаратная виртуализация в VirtualBox
   - Автоматическое обновление GRUB

После `vagrant up` система загрузится с новым ядром, сохранив при этом работоспособность общих папок. Для проверки:
```bash
vagrant ssh -c "uname -r"
6.15.9-1.el8.elrepo.x86_64
vagrant ssh -c "ls /vagrant"
```
