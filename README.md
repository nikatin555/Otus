Обновление ядра системы
Запустить ВМ c Ubuntu.
Обновить ядро ОС на новейшую стабильную версию из mainline-репозитория.
Оформить отчет в README-файле в GitHub-репозитории.

nik@ubuntu:~$ uname -r
6.8.0-59-generic
nik@ubuntu:~$ uname -p
x86_64
nik@ubuntu:~$ mkdir kernel && cd kernel
nik@ubuntu:~/kernel$  wget https://kernel.ubuntu.com/mainline/v6.14.4/amd64/linux-headers-6.14.4-061404-generic_6.14.4-061404.202504251003_amd64.deb && wget https://kernel.ubuntu.com/mainline/v6.14.4/amd64/linux-headers-6.14.4-061404_6.14.4-061404.202504251003_all.deb && wget https://kernel.ubuntu.com/mainline/v6.14.4/amd64/linux-image-unsigned-6.14.4-061404-generic_6.14.4-061404.202504251003_amd64.deb && wget https://kernel.ubuntu.com/mainline/v6.14.4/amd64/linux-modules-6.14.4-061404-generic_6.14.4-061404.202504251003_amd64.deb
nik@ubuntu:~/kernel$ ls
linux-headers-6.14.4-061404-generic_6.14.4-061404.202504251003_amd64.deb
linux-headers-6.14.4-061404_6.14.4-061404.202504251003_all.deb
linux-image-unsigned-6.14.4-061404-generic_6.14.4-061404.202504251003_amd64.deb
linux-modules-6.14.4-061404-generic_6.14.4-061404.202504251003_amd64.deb
nik@ubuntu:~/kernel$ sudo dpkg -i *.deb
nik@ubuntu:~/kernel$ ls -al /boot
total 184376
drwxr-xr-x  4 root root     4096 May  6 17:21 .
drwxr-xr-x 23 root root     4096 May  6 16:22 ..
-rw-------  1 root root  9981345 Apr 25 10:03 System.map-6.14.4-061404-generic
-rw-------  1 root root  9107440 Apr 11 20:44 System.map-6.8.0-59-generic
-rw-r--r--  1 root root   295497 Apr 25 10:03 config-6.14.4-061404-generic
-rw-r--r--  1 root root   287537 Apr 11 20:44 config-6.8.0-59-generic
drwxr-xr-x  5 root root     4096 May  6 17:21 grub
lrwxrwxrwx  1 root root       32 May  6 17:20 initrd.img -> initrd.img-6.14.4-061404-generic
-rw-r--r--  1 root root 70185221 May  6 17:21 initrd.img-6.14.4-061404-generic
-rw-r--r--  1 root root 68156674 May  6 16:23 initrd.img-6.8.0-59-generic
lrwxrwxrwx  1 root root       27 May  6 16:22 initrd.img.old -> initrd.img-6.8.0-59-generic
drwx------  2 root root    16384 May  6 16:02 lost+found
lrwxrwxrwx  1 root root       29 May  6 17:20 vmlinuz -> vmlinuz-6.14.4-061404-generic
-rw-------  1 root root 15737344 Apr 25 10:03 vmlinuz-6.14.4-061404-generic
-rw-------  1 root root 15001992 Apr 11 21:25 vmlinuz-6.8.0-59-generic
lrwxrwxrwx  1 root root       24 May  6 16:22 vmlinuz.old -> vmlinuz-6.8.0-59-generic
nik@ubuntu:~/kernel$ sudo update-grub
[sudo] password for nik:
nik@ubuntu:~/kernel$ sudo grub-set-default 0
nik@ubuntu:~/kernel$ sudo reboot
nik@ubuntu:~$ uname -r
6.14.4-061404-generic
