# Домашнее задание: Управление пакетами. Дистрибьюция софта 
## Сборка RPM-пакета и создание репозитория <br>
**Цель:**<br>
Научиться собирать RPM-пакеты.<br>
Создавать собственный RPM-репозиторий.

**Описание домашнего задания** <br>
Что нужно сделать: <br>
-    создать свой RPM (можно взять свое приложение, либо собрать к примеру Apache с определенными опциями); <br>
   - cоздать свой репозиторий и разместить там ранее собранный RPM; <br>
   - развернуть у себя через Nginx и дать ссылку на репозиторий.

## Создать свой RPM пакет
Версия нашей ОС:
[root@localhost ~]# cat /etc/oracle-release<br>
Oracle Linux Server release 9.6
 
-  Для данного задания нам понадобятся следующие установленные пакеты:
dnf install -y wget rpmdevtools rpm-build createrepo \ <br>
 dnf-utils cmake gcc git nano<br>

- Для примера возьмем пакет Nginx и соберем его с дополнительным модулем ngx_broli<br>
-  Загрузим SRPM пакет Nginx для дальнейшей работы над ним:
[root@localhost ~]# mkdir rpm && cd rpm<br>
[root@localhost rpm]# yumdownloader --source nginx

- При установке такого пакета в домашней директории создается дерево каталогов для сборки, далее поставим все зависимости для сборки пакета Nginx:<br>
[root@localhost rpm]# rpm -Uvh nginx*.src.rpm<br>
[root@localhost rpm]# yum-builddep nginx

- Также нужно скачать исходный код модуля ngx_brotli — он
потребуется при сборке:<br>
[root@localhost /]# cd /root<br>
[root@localhost ~]# git clone --recurse-submodules -j8 \ https://github.com/google/ngx_brotli<br>
[root@localhost ~]# cd ngx_brotli/deps/brotli<br>
[root@localhost brotli]#  mkdir out && cd out

- Собираем модуль ngx_brotli:<br>
[root@localhost out]#  cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..<br>
[root@localhost out]# cmake --build . --config Release -j 2 --target brotlienc<br>
[root@localhost out]# cd ../../../..

- Теперь можно приступить к сборке RPM пакета:<br>
[root@localhost ~]# cd ~/rpmbuild/SPECS/<br>
[root@localhost SPECS]#  rpmbuild -ba nginx.spec -D 'debug_package %{nil}' <br>
![alt text](image.png)

- Убедимся, что пакеты создались:<br>
[root@localhost SPECS]# ll  ~/rpmbuild/RPMS/x86_64<br>
![alt text](image-1.png)

-  Копируем пакеты в общий каталог:<br>
[root@localhost SPECS]# cp ~/rpmbuild/RPMS/noarch/* ~/rpmbuild/RPMS/x86_64/<br>
[root@localhost SPECS]#  cd ~/rpmbuild/RPMS/x86_64

- Теперь можно установить наш пакет и убедиться, что nginx работает:<br>
[root@localhost x86_64]# dnf localinstall *.rpm<br>
[root@localhost x86_64]# systemctl start nginx<br>
[root@localhost x86_64]# systemctl enable nginx<br>
[root@localhost x86_64]#  systemctl status ngin<br>
Unit ngin.service could not be found.

- Далее мы будем использовать его для доступа к своему репозиторию.<br>

## Создать свой репозиторий и разместить там ранее собранный RPM

- Теперь приступим к созданию своего репозитория. Директория для статики у Nginx по умолчанию /usr/share/nginx/html. Создадим там каталог repo:

[root@localhost x86_64]#  mkdir /usr/share/nginx/html/repo

- Копируем туда наши собранные RPM-пакеты:

[root@localhost x86_64]# cp ~/rpmbuild/RPMS/x86_64/*.rpm /usr/share/nginx/html/repo/

- Инициализируем репозиторий командой:<br>
[root@localhost x86_64]# createrepo /usr/share/nginx/html/repo/<br>
![alt text](image-2.png)

- Для прозрачности настроим в NGINX доступ к листингу каталога. В файле /etc/nginx/nginx.conf в блоке server добавим следующие директивы:<br>
[root@localhost x86_64]# nano /etc/nginx/nginx.conf<br>
![alt text](image-3.png)<br>

- Проверяем синтаксис и перезапускаем NGINX:<br>
[root@localhost x86_64]# nginx -t<br>
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok<br>
nginx: configuration file /etc/nginx/nginx.conf test is successful<br>
[root@localhost x86_64]# nginx -s reload

 Теперь ради интереса можно посмотреть в браузере или с помощью curl:<br>
 [root@localhost x86_64]# curl -a http://localhost/repo/<br>
 ![alt text](image-4.png)

- Все готово для того, чтобы протестировать репозиторий.<br>
- Добавим его в /etc/yum.repos.d:<br>
[root@localhost x86_64]# cat >> /etc/yum.repos.d/otus.repo << EOF<br>
![alt text](image-5.png)

- Убедимся, что репозиторий подключился и посмотрим, что в нем есть:<br>
![alt text](image-6.png)

- Добавим пакет в наш репозиторий:<br>
[root@localhost x86_64]#  cd /usr/share/nginx/html/repo/<br>
[root@localhost repo]#  wget https://repo.percona.com/yum/percona-release-latest.noarch.rpm

- Обновим список пакетов в репозитории:<br>
![alt text](image-7.png)

- Так как Nginx у нас уже стоит, установим репозиторий percona-release:<br>
[root@localhost repo]# dnf install -y percona-release.noarch

-  Обновить репозиторий:<br>
![alt text](image-8.png)<br>

![alt text](image-9.png)
