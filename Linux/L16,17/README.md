# 16.17 Автоматизация администрирования. Ansible

## Домашнее задание

Первые шаги с Ansible

**Цель:**

Написать первые шаги с Ansible.

Описание/Пошаговая инструкция выполнения домашнего задания:

Что нужно сделать?

Подготовить стенд на Vagrant как минимум с одним сервером. На этом сервере используя Ansible необходимо развернуть nginx со следующими условиями:

- необходимо использовать модуль yum/apt;
- конфигурационные файлы должны быть взяты из шаблона jinja2 с перемененными;
- после установки nginx должен быть в режиме enabled в systemd;
- должен быть использован notify для старта nginx после установки;
- сайт должен слушать на нестандартном порту - 8080, для этого использовать переменные в Ansible.

* Сделать все это с использованием Ansible роли


root@localhost:/home/nik/Загрузки# ansible --version
ansible [core 2.18.7]
  config file = None
  configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /root/.local/lib/python3.12/site-packages/ansible
  ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
  executable location = /root/.local/bin/ansible
  python version = 3.12.9 (main, Jun 20 2025, 00:00:00) [GCC 14.2.1 20250110 (Red Hat 14.2.1-7)] (/bin/python3)
  jinja version = 3.1.6
  libyaml = True
root@localhost:/home/nik/Загрузки#  python3 -m pip -V
pip 25.2 from /root/.local/lib/python3.12/site-packages/pip (python 3.12)
1  cd /home/nik/Загрузки
    
sudo dnf install -y kernel-devel kernel-headers gcc make perl elfutils-libelf-devel
sudo dnf install -y ./VirtualBox-7.1-7.1.10_169112_fedora40-1.x86_64.rpm -y
pipx install --include-deps ansible

ansible --version
ansible [core 2.18.7]
  config file = /etc/ansible/ansible.cfg
  configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /root/.local/lib/python3.12/site-packages/ansible
  ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
  executable location = /root/.local/bin/ansible
  python version = 3.12.9 (main, Jun 20 2025, 00:00:00) [GCC 14.2.1 20250110 (Red Hat 14.2.1-7)] (/bin/python3)
  jinja version = 3.1.6
  libyaml = True

python3 get-pip.py --user
python3 -m pip install --user ansible
python3 -m pip -V
pip 25.2 from /root/.local/lib/python3.12/site-packages/pip (python 3.12)

dnf install ansible-collection-community-general

