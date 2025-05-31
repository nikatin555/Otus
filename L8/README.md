# Домашнее задание

Работа с загрузчиком<br>
__Задание__ <br>
1. Включить отображение меню Grub.<br>
2. Попасть в систему без пароля несколькими способами.<br>
3. Установить систему с LVM, после чего переименовать VG.

**Цель:**

- Научиться попадать в систему без пароля;<br>
- Устанавливать систему с LVM и переименовывать в VG.

Для выполнения домашнего задания использовались ОС:

- Oracle Linux release 9.5 c заблокированной учетной записью root:<br>
[root@localhost ~]# passwd -S root<br>
root LK 1969-12-31 0 99999 7 -1 (Пароль заблокирован.)

- Ubuntu 24.04 c установленным паролем на root:

## Включить отображение меню Grub

По умолчанию меню загрузчика Grub скрыто и нет задержки при загрузке. Для отображения меню нужно отредактировать конфигурационный файл:<br>
nano /etc/default/grub

Комментируем строку, скрывающую меню и ставим задержку для выбора пункта меню в 10 секунд.
#GRUB_TIMEOUT_STYLE=hidden
GRUB_TIMEOUT=10

Oracle Linux:<br>
![alt text](image.png)
Ubuntu:<br>
![alt text](image-1.png)

Обновляем конфигурацию загрузчика и перезагружаемся для проверки:
Oracle Linux:<br> grub2-set-default 1

Ubuntu:<br> update-grub

Перезагружаем системы, попадаем в меню загрузчика, нажимаем "e":<br>
Oracle Linux:<br>
![alt text](image-2.png)
Ubuntu:<br>
![alt text](image-3.png)

## Попасть в систему без пароля несколькими способами <br>
### Способ 1. init=/bin/bash

Oracle Linux: В конце строки, начинающейся с linux, добавляем **rd.break** и нажимаем сtrl-x для загрузки в систему:<br>
![alt text](image-5.png)<br>
Ubuntu: В конце строки, начинающейся с linux, добавляем **init=/bin/bash** , меняем **ro** на **rw** , и нажимаем сtrl-x для загрузки в систему:<br>
![alt text](image-4.png)

Сброс пароля root в ubuntu:<br>
![alt text](image-6.png) <br>
перезагружаю систему и успешно авторизируюсь под root  с новым паролем:<br>
![alt text](image-7.png)

Сброс пароля root в Oracle Linux:<br>
Монтирование файловой системы в режим записи:<br>
 mount -o remount,rw /sysroot

 Заходим в chroot окружение:<br>
chroot /sysroot

 Сброс пароля и активация root:<br>
 nano /etc/shadow

в строке для root, удаляе всё во втором поле (после root:) и знак "!", для разблокировки учетной записи:<br>
root:::0:99999:7:::

Выходим из chroot: Ctrl+D<br>
Перезагружаемся: reboot -f

Заходим в систему под root без пароля и назначем новый пароль:<br>
![alt text](image-8.png)

## Способ 2. Recovery mode

В меню загрузчика на первом уровне выбрать второй пункт (Advanced options…), далее загрузить пункт меню с указанием recovery mode в названии.<br> 
Получим меню режима восстановления.<br>
![alt text](image-9.png)

Система загружается сразу в консоль, нажимаем Enter и меняем пароль root:<br>
![alt text](image-10.png)

Перезагружаемся, проверяем вход с новым паролем:<br>
![alt text](image-11.png)

## Установить систему с LVM, после чего переименовать VG

Мы установили систему Ubuntu 24.04 со стандартной разбивкой диска с использованием  LVM.<br>
Первым делом посмотрим текущее состояние системы (список Volume Group):<br>
root@ubuntu:~# vgs <br>
![alt text](image-12.png)

Нас интересует вторая строка с именем Volume Group. Приступим к переименованию:<br>
root@ubuntu:~# vgrename ubuntu-vg ubuntu-otus<br>
  Volume group "ubuntu-vg" successfully renamed to "ubuntu-otus"

Далее правим /boot/grub/grub.cfg. Везде заменяем старое название VG на новое (в файле дефис меняется на два дефиса ubuntu--vg ubuntu--otus):<br>
root@ubuntu:~# nano  /boot/grub/grub.cfg
 
После чего можем перезагружаться и, если все сделано правильно, успешно грузимся с новым именем Volume Group и проверяем:<br>
![alt text](image-13.png)



