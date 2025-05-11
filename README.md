Домашнее задание: работа с mdadm
Задание
• Добавить в виртуальную машину несколько дисков
• Собрать RAID-0/1/5/10 на выбор
• Сломать и починить RAID
• Создать GPT таблицу, пять разделов и смонтировать их в системе.
На проверку отправьте:
скрипт для создания рейда, 
отчет по командам для починки RAID и созданию разделов.

скрипт для создания рейда:
mdadm --create --verbose /dev/md0 -l 5 -n 3 /dev/sd{b,c,d}
root@ubuntu:/home/nik# mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Sun May 11 15:55:50 2025
        Raid Level : raid5
        Array Size : 2093056 (2044.00 MiB 2143.29 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 3
     Total Devices : 3
       Persistence : Superblock is persistent

       Update Time : Sun May 11 15:56:04 2025
             State : clean
    Active Devices : 3
   Working Devices : 3
    Failed Devices : 0
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : ubuntu:0  (local to host ubuntu)
              UUID : 48beda86:13ef616c:b9a4d8da:d92e82fc
            Events : 18

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       1       8       32        1      active sync   /dev/sdc
       3       8       48        2      active sync   /dev/sdd



отчет по командам для починки RAID и созданию разделов:

root@ubuntu:/home/nik# mdadm /dev/md0 --fail /dev/sdb
mdadm: set /dev/sdb faulty in /dev/md0
root@ubuntu:/home/nik# cat /proc/mdstat
Personalities : [linear] [raid0] [raid1] [raid6] [raid5] [raid4] [raid10]
md0 : active raid5 sdd[3] sdc[1] sdb[0](F)
      2093056 blocks super 1.2 level 5, 512k chunk, algorithm 2 [3/2] [_UU]

unused devices: <none>
root@ubuntu:/home/nik# mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Sun May 11 15:55:50 2025
        Raid Level : raid5
        Array Size : 2093056 (2044.00 MiB 2143.29 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 3
     Total Devices : 3
       Persistence : Superblock is persistent

       Update Time : Sun May 11 15:58:10 2025
             State : clean, degraded
    Active Devices : 2
   Working Devices : 2
    Failed Devices : 1
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : ubuntu:0  (local to host ubuntu)
              UUID : 48beda86:13ef616c:b9a4d8da:d92e82fc
            Events : 20

    Number   Major   Minor   RaidDevice State
       -       0        0        0      removed
       1       8       32        1      active sync   /dev/sdc
       3       8       48        2      active sync   /dev/sdd

       0       8       16        -      faulty   /dev/sdb
root@ubuntu:/home/nik# mdadm /dev/md0 --remove /dev/sdb
mdadm: hot removed /dev/sdb from /dev/md0
root@ubuntu:/home/nik# mdadm /dev/md0 --add /dev/sde
mdadm: added /dev/sde
root@ubuntu:/home/nik# cat /proc/mdstat
Personalities : [linear] [raid0] [raid1] [raid6] [raid5] [raid4] [raid10]
md0 : active raid5 sde[4] sdd[3] sdc[1]
      2093056 blocks super 1.2 level 5, 512k chunk, algorithm 2 [3/3] [UUU]

unused devices: <none>
root@ubuntu:/home/nik# mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Sun May 11 15:55:50 2025
        Raid Level : raid5
        Array Size : 2093056 (2044.00 MiB 2143.29 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 3
     Total Devices : 3
       Persistence : Superblock is persistent

       Update Time : Sun May 11 15:59:46 2025
             State : clean
    Active Devices : 3
   Working Devices : 3
    Failed Devices : 0
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : ubuntu:0  (local to host ubuntu)
              UUID : 48beda86:13ef616c:b9a4d8da:d92e82fc
            Events : 40

    Number   Major   Minor   RaidDevice State
       4       8       64        0      active sync   /dev/sde
       1       8       32        1      active sync   /dev/sdc
       3       8       48        2      active sync   /dev/sdd
root@ubuntu:/home/nik# parted -s /dev/md0 mklabel gpt
root@ubuntu:/home/nik# parted /dev/md0 mkpart primary ext4 0% 20%
Information: You may need to update /etc/fstab.

root@ubuntu:/home/nik# parted /dev/md0 mkpart primary ext4 20% 40%
Information: You may need to update /etc/fstab.

root@ubuntu:/home/nik# parted /dev/md0 mkpart primary ext4 40% 60%
Information: You may need to update /etc/fstab.

root@ubuntu:/home/nik# parted /dev/md0 mkpart primary ext4 60% 80%
Information: You may need to update /etc/fstab.

root@ubuntu:/home/nik# parted /dev/md0 mkpart primary ext4 80% 100%
Information: You may need to update /etc/fstab.

root@ubuntu:/home/nik# for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done

root@ubuntu:/home/nik# mkdir -p /raid/part{1,2,3,4,5}
root@ubuntu:/home/nik# for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done
root@ubuntu:/home/nik# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sda                         8:0    0   40G  0 disk
├─sda1                      8:1    0    1M  0 part
├─sda2                      8:2    0    2G  0 part  /boot
└─sda3                      8:3    0   38G  0 part
  └─ubuntu--vg-ubuntu--lv 252:0    0   19G  0 lvm   /
sdb                         8:16   0    1G  0 disk
sdc                         8:32   0    1G  0 disk
└─md0                       9:0    0    2G  0 raid5
  ├─md0p1                 259:1    0  408M  0 part  /raid/part1
  ├─md0p2                 259:4    0  409M  0 part  /raid/part2
  ├─md0p3                 259:5    0  408M  0 part  /raid/part3
  ├─md0p4                 259:8    0  409M  0 part  /raid/part4
  └─md0p5                 259:9    0  408M  0 part  /raid/part5
sdd                         8:48   0    1G  0 disk
└─md0                       9:0    0    2G  0 raid5
  ├─md0p1                 259:1    0  408M  0 part  /raid/part1
  ├─md0p2                 259:4    0  409M  0 part  /raid/part2
  ├─md0p3                 259:5    0  408M  0 part  /raid/part3
  ├─md0p4                 259:8    0  409M  0 part  /raid/part4
  └─md0p5                 259:9    0  408M  0 part  /raid/part5
sde                         8:64   0    1G  0 disk
└─md0                       9:0    0    2G  0 raid5
  ├─md0p1                 259:1    0  408M  0 part  /raid/part1
  ├─md0p2                 259:4    0  409M  0 part  /raid/part2
  ├─md0p3                 259:5    0  408M  0 part  /raid/part3
  ├─md0p4                 259:8    0  409M  0 part  /raid/part4
  └─md0p5                 259:9    0  408M  0 part  /raid/part5
sdf                         8:80   0    1G  0 disk
sr0                        11:0    1 1024M  0 rom
root@ubuntu:/home/nik# fdisk -l
Disk /dev/sda: 40 GiB, 42949672960 bytes, 83886080 sectors
Disk model: VBOX HARDDISK
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: 5346EFE8-0D2C-4D4B-8153-CC8E496A40A8

Device       Start      End  Sectors Size Type
/dev/sda1     2048     4095     2048   1M BIOS boot
/dev/sda2     4096  4198399  4194304   2G Linux filesystem
/dev/sda3  4198400 83884031 79685632  38G Linux filesystem


Disk /dev/sdb: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk model: VBOX HARDDISK
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdc: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk model: VBOX HARDDISK
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdd: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk model: VBOX HARDDISK
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sde: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk model: VBOX HARDDISK
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdf: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk model: VBOX HARDDISK
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/mapper/ubuntu--vg-ubuntu--lv: 19 GiB, 20396900352 bytes, 39837696 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/md0: 2 GiB, 2143289344 bytes, 4186112 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 524288 bytes / 1048576 bytes
Disklabel type: gpt
Disk identifier: F0FD03EE-2C34-4969-BD16-89B44B469C2B

Device       Start     End Sectors  Size Type
/dev/md0p1    2048  837631  835584  408M Linux filesystem
/dev/md0p2  837632 1675263  837632  409M Linux filesystem
/dev/md0p3 1675264 2510847  835584  408M Linux filesystem
/dev/md0p4 2510848 3348479  837632  409M Linux filesystem
/dev/md0p5 3348480 4184063  835584  408M Linux filesystem
