# 28 Архитектура сетей

Я помогу вам с выполнением этого домашнего задания. Давайте разберем обе части.

## Теоретическая часть

### Анализ подсетей:

**Сеть office1 (192.168.2.0/24):**
- 192.168.2.0/26 (dev) - 62 узла, broadcast: 192.168.2.63
- 192.168.2.64/26 (test servers) - 62 узла, broadcast: 192.168.2.127  
- 192.168.2.128/26 (managers) - 62 узла, broadcast: 192.168.2.191
- 192.168.2.192/26 (office hardware) - 62 узла, broadcast: 192.168.2.255
- **Свободные:** нет (все /26 покрывают весь /24)

**Сеть office2 (192.168.1.0/24):**
- 192.168.1.0/25 (dev) - 126 узлов, broadcast: 192.168.1.127
- 192.168.1.128/26 (test servers) - 62 узла, broadcast: 192.168.1.191
- 192.168.1.192/26 (office hardware) - 62 узла, broadcast: 192.168.1.255
- **Свободные:** 192.168.1.128/25 не полностью использован

**Сеть central (192.168.0.0/24):**
- 192.168.0.0/28 (directors) - 14 узлов, broadcast: 192.168.0.15
- 192.168.0.32/28 (office hardware) - 14 узлов, broadcast: 192.168.0.47
- 192.168.0.64/26 (wifi) - 62 узла, broadcast: 192.168.0.127
- **Свободные:** 192.168.0.16/28, 192.168.0.48/28, 192.168.0.128/25

**Ошибок в разбиении нет.**

## Практическая часть

### 1. Установка и настройка

Создайте директорию и скачайте Vagrantfile:

```bash
mkdir -p /etc/L28
cd /etc/L28
curl -O https://raw.githubusercontent.com/erlong15/otus-linux/network/Vagrantfile
```

### 2. Vagrantfile с дополнительными интерфейсами

Дополните Vagrantfile конфигурацией сетевых интерфейсов:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"
  
  # inetRouter
  config.vm.define "inetRouter" do |inetRouter|
    inetRouter.vm.hostname = "inetRouter"
    inetRouter.vm.network "private_network", ip: "192.168.255.1", virtualbox__intnet: "central-inet"
    inetRouter.vm.provision "shell", path: "scripts/inetRouter.sh"
  end

  # centralRouter
  config.vm.define "centralRouter" do |centralRouter|
    centralRouter.vm.hostname = "centralRouter"
    centralRouter.vm.network "private_network", ip: "192.168.255.2", virtualbox__intnet: "central-inet"
    centralRouter.vm.network "private_network", ip: "192.168.0.1", virtualbox__intnet: "central-office1"
    centralRouter.vm.network "private_network", ip: "192.168.1.1", virtualbox__intnet: "central-office2"
    centralRouter.vm.provision "shell", path: "scripts/centralRouter.sh"
  end

  # office1Router
  config.vm.define "office1Router" do |office1Router|
    office1Router.vm.hostname = "office1Router"
    office1Router.vm.network "private_network", ip: "192.168.0.2", virtualbox__intnet: "central-office1"
    office1Router.vm.network "private_network", ip: "192.168.2.1", virtualbox__intnet: "office1-internal"
    office1Router.vm.provision "shell", path: "scripts/office1Router.sh"
  end

  # office2Router
  config.vm.define "office2Router" do |office2Router|
    office2Router.vm.hostname = "office2Router"
    office2Router.vm.network "private_network", ip: "192.168.1.2", virtualbox__intnet: "central-office2"
    office2Router.vm.network "private_network", ip: "192.168.1.129", virtualbox__intnet: "office2-internal"
    office2Router.vm.provision "shell", path: "scripts/office2Router.sh"
  end

  # centralServer
  config.vm.define "centralServer" do |centralServer|
    centralServer.vm.hostname = "centralServer"
    centralServer.vm.network "private_network", ip: "192.168.0.33", virtualbox__intnet: "central-internal"
    centralServer.vm.provision "shell", path: "scripts/centralServer.sh"
  end

  # office1Server
  config.vm.define "office1Server" do |office1Server|
    office1Server.vm.hostname = "office1Server"
    office1Server.vm.network "private_network", ip: "192.168.2.65", virtualbox__intnet: "office1-internal"
    office1Server.vm.provision "shell", path: "scripts/office1Server.sh"
  end

  # office2Server
  config.vm.define "office2Server" do |office2Server|
    office2Server.vm.hostname = "office2Server"
    office2Server.vm.network "private_network", ip: "192.168.1.130", virtualbox__intnet: "office2-internal"
    office2Server.vm.provision "shell", path: "scripts/office2Server.sh"
  end
end
```

### 3. Создайте директорию scripts и файлы настройки

```bash
mkdir scripts
```

**scripts/inetRouter.sh:**
```bash
#!/bin/bash

# Disable default NAT
systemctl stop NetworkManager
systemctl disable NetworkManager

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Configure interfaces
cat > /etc/sysconfig/network-scripts/ifcfg-eth1 << EOF
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.255.1
NETMASK=255.255.255.0
EOF

# Start network
systemctl restart network

# Configure NAT for internet access
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Save iptables rules
service iptables save
```

**scripts/centralRouter.sh:**
```bash
#!/bin/bash

# Disable default NAT
systemctl stop NetworkManager
systemctl disable NetworkManager

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Configure interfaces
cat > /etc/sysconfig/network-scripts/ifcfg-eth1 << EOF
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.255.2
NETMASK=255.255.255.0
GATEWAY=192.168.255.1
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-eth2 << EOF
DEVICE=eth2
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.0.1
NETMASK=255.255.255.0
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-eth3 << EOF
DEVICE=eth3
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.1.1
NETMASK=255.255.255.0
EOF

# Start network
systemctl restart network

# Add routes
ip route add 192.168.2.0/24 via 192.168.0.2
ip route add 192.168.1.128/26 via 192.168.1.2
ip route add 192.168.1.192/26 via 192.168.1.2

# Configure NAT
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
```

**scripts/office1Router.sh:**
```bash
#!/bin/bash

# Disable default NAT
systemctl stop NetworkManager
systemctl disable NetworkManager

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Configure interfaces
cat > /etc/sysconfig/network-scripts/ifcfg-eth1 << EOF
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.0.2
NETMASK=255.255.255.0
GATEWAY=192.168.0.1
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-eth2 << EOF
DEVICE=eth2
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.2.1
NETMASK=255.255.255.192
EOF

# Start network
systemctl restart network

# Add default route
ip route add default via 192.168.0.1
```

**scripts/office2Router.sh:**
```bash
#!/bin/bash

# Disable default NAT
systemctl stop NetworkManager
systemctl disable NetworkManager

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Configure interfaces
cat > /etc/sysconfig/network-scripts/ifcfg-eth1 << EOF
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.1.2
NETMASK=255.255.255.0
GATEWAY=192.168.1.1
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-eth2 << EOF
DEVICE=eth2
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.1.129
NETMASK=255.255.255.192
EOF

# Start network
systemctl restart network

# Add default route
ip route add default via 192.168.1.1
```

**scripts/centralServer.sh:**
```bash
#!/bin/bash

# Disable default NAT
systemctl stop NetworkManager
systemctl disable NetworkManager

# Configure interface
cat > /etc/sysconfig/network-scripts/ifcfg-eth1 << EOF
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.0.33
NETMASK=255.255.255.240
GATEWAY=192.168.0.1
DNS1=8.8.8.8
EOF

# Start network
systemctl restart network
```

**scripts/office1Server.sh:**
```bash
#!/bin/bash

# Disable default NAT
systemctl stop NetworkManager
systemctl disable NetworkManager

# Configure interface
cat > /etc/sysconfig/network-scripts/ifcfg-eth1 << EOF
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.2.65
NETMASK=255.255.255.192
GATEWAY=192.168.2.1
DNS1=8.8.8.8
EOF

# Start network
systemctl restart network
```

**scripts/office2Server.sh:**
```bash
#!/bin/bash

# Disable default NAT
systemctl stop NetworkManager
systemctl disable NetworkManager

# Configure interface
cat > /etc/sysconfig/network-scripts/ifcfg-eth1 << EOF
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.1.130
NETMASK=255.255.255.192
GATEWAY=192.168.1.129
DNS1=8.8.8.8
EOF

# Start network
systemctl restart network
```

### 4. Запуск стенда

```bash
# Сделайте файлы исполняемыми
chmod +x scripts/*.sh

# Запустите Vagrant
vagrant up

# Проверьте доступность
vagrant ssh inetRouter
ping 192.168.2.65  # из office1Server
ping 192.168.1.130 # из office2Server
ping 8.8.8.8       # проверка интернета
```

### 5. Ansible плейбук (дополнительно)

Создайте `ansible/playbook.yml` для автоматической настройки:

```yaml
---
- name: Configure network infrastructure
  hosts: all
  become: yes
  tasks:
    - name: Disable NetworkManager
      service:
        name: NetworkManager
        state: stopped
        enabled: no

    - name: Enable IP forwarding
      sysctl:
        name: net.ipv4.ip_forward
        value: '1'
        state: present
        reload: yes

- name: Configure routers
  hosts: routers
  become: yes
  tasks:
    - name: Configure iptables rules
      iptables:
        chain: POSTROUTING
        table: nat
        jump: MASQUERADE
        out_interface: eth0
```

### Проверка работы:

1. Все сервера должны пинговать друг друга
2. Интернет-трафик идет через inetRouter
3. NAT отключен на всех интерфейсах eth0
4. Маршрутизация работает корректно между всеми сетями

Теперь у вас есть полная сетевая инфраструктура с настроенной маршрутизацией и доступом в интернет!