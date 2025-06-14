# Systemd — создание unit-файла

# Домашнее задание

1. Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/default).<br>
2. Установить spawn-fcgi и создать unit-файл (spawn-fcgi.sevice) с помощью переделки init-скрипта (https://gist.github.com/cea2k/1318020).<br>
3. Доработать unit-файл Nginx (nginx.service) для запуска нескольких инстансов сервера с разными конфигурационными файлами одновременно.<br>

## Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова

Cоздаём файл с конфигурацией для сервиса в директории /etc/default - из неё сервис будет брать необходимые переменные:<br>
nano /etc/default/watchlog

![alt text](image-5.png)

Затем создаем /var/log/watchlog.log и пишем туда строки на своё усмотрение,
плюс ключевое слово ‘ALERT’

![alt text](image-6.png)

Создадим скрипт:
nano /opt/watchlog.sh

![alt text](image-7.png)

Команда logger отправляет лог в системный журнал.
Добавим права на запуск файла:

 chmod +x /opt/watchlog.sh

 Создадим юнит для сервиса:

 cat > /etc/systemd/system/watchlog.service

 ![alt text](image-8.png)

Создадим юнит для таймера:

nano /etc/systemd/system/watchlog.timer

![alt text](image-9.png)

Затем запустим timer:

systemctl start watchlog.timer

И убедимся в результате:

tail -n 1000 /var/log/syslog  | grep word

Появилась ошибка: данного файла не существует. Попробуем посмотреть ошибку в бинарном формате через journalctl:

journalctl | grep "word"
journalctl | grep "word"**
journalctl | grep word
journalctl | grep "I found word"

Нашей ошибки нет. Посмотрим в полном журнале:
journalctl -xe 

Нашей ошибки попрежнему нет.  Попробуем устаноывить syslog:

apt install rsyslog -y

 systemctl enable --now rsyslog


systemctl start watchlog.service

systemctl restart watchlog.timer

Ошибка появилась:

![alt text](image-11.png)

![alt text](image-12.png)

 
## Установить spawn-fcgi и создать unit-файл (spawn-fcgi.sevice) с помощью переделки init-скрипта

Устанавливаем spawn-fcgi и необходимые для него пакеты:

apt install spawn-fcgi php php-cgi php-cli \
 apache2 libapache2-mod-fcgid -y

необходимо создать файл с настройками для будущего сервиса в файле /etc/spawn-fcgi/fcgi.conf:

mkdir /etc/spawn-fcgi/ && touch/etc/spawn-fcgi/fcgi.conf

nano /etc/spawn-fcgi/fcgi.conf

![alt text](image-13.png)

Cам юнит-файл будет следующего вида:



cat > /etc/systemd/system/spawn-fcgi.service




Проверим работу:

![alt text](image-1.png)

![alt text](image-2.png)

проверяем ошибки:<br>
![alt text](image-3.png)<br>
![alt text](image-4.png)<br>
