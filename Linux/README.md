# Домашнее задание
## На виртуальной машине с Ubuntu 24.04 и LVM.
## Уменьшить том под / до 8G.
Выделить том под /home.
Выделить том под /var - сделать в mirror.
/home - сделать том для снапшотов.
Прописать монтирование в fstab. Попробовать с разными опциями и разными файловыми системами (на выбор).
Работа со снапшотами:
сгенерить файлы в /home/;
снять снапшот;
удалить часть файлов;
восстановится со снапшота.
[root@ubuntu:~]# pvcreate /dev/sdg
  Physical volume "/dev/sdg" successfully created.
[root@ubuntu:~]# vgcreate vg_root /dev/sdg
  Volume group "vg_root" successfully created
[root@ubuntu:~]# lvcreate -n lv_root -l +100%FREE /dev/vg_root
  Logical volume "lv_root" created.
[root@ubuntu:~]# mkfs.ext4 /dev/vg_root/lv_root
[root@ubuntu:~]# mount /dev/vg_root/lv_root /mnt
[root@ubuntu:~]# rsync -avxHAX --progress / /mnt/
[root@ubuntu:~]# for i in /proc/ /sys/ /dev/ /run/ /boot/; \
 do mount --bind $i /mnt/$i; done
[root@ubuntu:~]# chroot /mnt/
[root@ubuntu /]# grub-mkconfig -o /boot/grub/grub.cfg
[root@ubuntu /]# update-initramfs -u
[root@ubuntu /]# exit
[root@ubuntu:~]# reboot
[root@ubuntu:~]# lsblk
[root@ubuntu:~]# lvremove /dev/ubuntu-vg/ubuntu-lv
Do you really want to remove and DISCARD active logical volume ubuntu-vg/ubuntu-lv? [y/n]: y
  Logical volume "ubuntu-lv" successfully removed.
[root@ubuntu:~]# lvcreate -n ubuntu-vg/ubuntu-lv -L 8G /dev/ubuntu-vg
WARNING: ext4 signature detected on /dev/ubuntu-vg/ubuntu-lv at offset 1080. Wipe it? [y/n]: y
  Wiping ext4 signature on /dev/ubuntu-vg/ubuntu-lv.
  Logical volume "ubuntu-lv" created.
[root@ubuntu:~]# mkfs.ext4 /dev/ubuntu-vg/ubuntu-lv
[root@ubuntu:~]# mount /dev/ubuntu-vg/ubuntu-lv /mnt
[root@ubuntu:~]# rsync -avxHAX --progress / /mnt/
[root@ubuntu:~]# for i in /proc/ /sys/ /dev/ /run/ /boot/; \
 do mount --bind $i /mnt/$i; done
[root@ubuntu:~]# chroot /mnt/
[root@ubuntu /]# grub-mkconfig -o /boot/grub/grub.cfg
[root@ubuntu /]# update-initramfs -u
[root@ubuntu boot]# pvcreate /dev/sdc /dev/sdd
  Physical volume "/dev/sdc" successfully created.
  Physical volume "/dev/sdd" successfully created.
[root@ubuntu boot]# vgcreate vg_var /dev/sdc /dev/sdd
  Volume group "vg_var" successfully created
[root@ubuntu boot]# lvcreate -L 950M -m1 -n lv_var vg_var
  Rounding up size to full physical extent 952.00 MiB
  Logical volume "lv_var" created.
[root@ubuntu boot]# mkfs.ext4 /dev/vg_var/lv_var
[root@ubuntu boot]# mount /dev/vg_var/lv_var /mnt
[root@ubuntu boot]# cp -aR /var/* /mnt/
[root@ubuntu boot]# mkdir /tmp/oldvar && mv /var/* /tmp/oldvar
[root@ubuntu boot]# umount /mnt
[root@ubuntu boot]# mount /dev/vg_var/lv_var /var
[root@ubuntu boot]# echo "`blkid | grep var: | awk '{print $2}'` \
 /var ext4 defaults 0 0" >> /etc/fstab
root@ubuntu:~#exit
root@ubuntu:~#reboot
root@ubuntu:~# lvremove /dev/vg_root/lv_root
Do you really want to remove and DISCARD active logical volume vg_root/lv_root? [y/n]: y
  Logical volume "lv_root" successfully removed.
root@ubuntu:~# vgremove /dev/vg_root
  Volume group "vg_root" successfully removed
root@ubuntu:~# pvremove /dev/sdg
  Labels on physical volume "/dev/sdg" successfully wiped.
root@ubuntu:~# lvcreate -n LogVol_Home -L 2G /dev/ubuntu-vg
  Logical volume "LogVol_Home" created.
root@ubuntu:~# mkfs.ext4 /dev/ubuntu-vg/LogVol_Home
root@ubuntu:~#  mount /dev/ubuntu-vg/LogVol_Home /mnt/
root@ubuntu:~# cp -aR /home/* /mnt/
root@ubuntu:~# rm -rf /home/*
root@ubuntu:~# umount /mnt
root@ubuntu:~# mount /dev/ubuntu-vg/LogVol_Home /home/
root@ubuntu:~# echo "`blkid | grep Home | awk '{print $2}'` \
 /home xfs defaults 0 0" >> /etc/fstab
root@ubuntu:~# nano /etc/fstab
root@ubuntu:~# touch /home/file{1..20}
root@ubuntu:~# ls /home/
file1  file10  file11  file12  file13  file14  file15  file16  file17  file18  file19  file2  file20  file3  file4  file5  file6  file7  file8  file9  lost+found  nik
root@ubuntu:~# lvcreate -L 100MB -s -n home_snap \
 /dev/ubuntu-vg/LogVol_Home
  Logical volume "home_snap" created.
root@ubuntu:~# rm -f /home/file{11..20}
root@ubuntu:~# ls /home/
file1  file10  file2  file3  file4  file5  file6  file7  file8  file9  lost+found  nik
root@ubuntu:~# umount /home
root@ubuntu:~# lvconvert --merge /dev/ubuntu-vg/home_snap
  Merging of volume ubuntu-vg/home_snap started.
  ubuntu-vg/LogVol_Home: Merged: 100.00%
root@ubuntu:~# mount /dev/mapper/ubuntu--vg-LogVol_Home /home
mount: (hint) your fstab has been modified, but systemd still uses
       the old version; use 'systemctl daemon-reload' to reload.
root@ubuntu:~# ls -al /home
total 28
drwxr-xr-x  4 root root  4096 May 15 14:18 .
drwxr-xr-x 23 root root  4096 May  6 16:22 ..
-rw-r--r--  1 root root     0 May 15 14:18 file1
-rw-r--r--  1 root root     0 May 15 14:18 file10
-rw-r--r--  1 root root     0 May 15 14:18 file11
-rw-r--r--  1 root root     0 May 15 14:18 file12
-rw-r--r--  1 root root     0 May 15 14:18 file13
-rw-r--r--  1 root root     0 May 15 14:18 file14
-rw-r--r--  1 root root     0 May 15 14:18 file15
-rw-r--r--  1 root root     0 May 15 14:18 file16
-rw-r--r--  1 root root     0 May 15 14:18 file17
-rw-r--r--  1 root root     0 May 15 14:18 file18
-rw-r--r--  1 root root     0 May 15 14:18 file19
-rw-r--r--  1 root root     0 May 15 14:18 file2
-rw-r--r--  1 root root     0 May 15 14:18 file20
-rw-r--r--  1 root root     0 May 15 14:18 file3
-rw-r--r--  1 root root     0 May 15 14:18 file4
-rw-r--r--  1 root root     0 May 15 14:18 file5
-rw-r--r--  1 root root     0 May 15 14:18 file6
-rw-r--r--  1 root root     0 May 15 14:18 file7
-rw-r--r--  1 root root     0 May 15 14:18 file8
-rw-r--r--  1 root root     0 May 15 14:18 file9
drwx------  2 root root 16384 May 15 14:12 lost+found
drwxr-x---  5 nik  nik   4096 May  6 18:30 nik
