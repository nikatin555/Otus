# 3. Установка PostgreSQL
# Домашнее задание
Установка и настройка PostgteSQL в контейнере Docker

__Цель:__<br>
- установить PostgreSQL в Docker контейнере;<br>
- настроить контейнер для внешнего подключения.

**Описание выполнения домашнего задания:**

    - создать ВМ с Ubuntu 20.04/22.04 или развернуть докер любым удобным способом; <br>
    - поставить на нем Docker Engine;
    - сделать каталог /var/lib/postgres;
    - развернуть контейнер с PostgreSQL 15 смонтировав в него /var/lib/postgresql;
    - развернуть контейнер с клиентом postgres;
    - подключится из контейнера с клиентом к контейнеру с сервером и сделать таблицу с парой строк;
    - подключится к контейнеру с сервером с ноутбука/компьютера извне инстансов ЯО/места установки докера;
    - удалить контейнер с сервером;
    - создать его заново;
    - подключится снова из контейнера с клиентом к контейнеру с сервером
    проверить, что данные остались на месте;
    -  оставляйте в ЛК ДЗ комментарии что и как вы делали и как боролись с проблемами.

## создать ВМ с Ubuntu 20.04/22.04 или развернуть докер любым удобным способом

Для выполнения ДЗ была выбрана более новая версия Ubuntu 24.04.2 LTS, установлена минимальная система на VM VirtualBox 7.1.8.

Обновляем пакеты:<br>
sudo apt update && sudo apt upgrade -y

## Установка Docker Engine

Устанавливаем зависимости:<br>
sudo apt install -y ca-certificates curl gnupg

Добавляем ключ Docker:<br>
sudo install -m 0755 -d /etc/apt/keyrings<br>
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg<br>
sudo chmod a+r /etc/apt/keyrings/docker.gpg

Добавляем репозиторий:<br>
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

Устанавливаем Docker:<br>
sudo apt update<br>
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

Проверяем установку:<br>
sudo docker --version<br>
![alt text](image.png)

 ## Создание каталога для данных PostgreSQL: /var/lib/postgres

Cоздадим сам каталог:<br>
mkdir -p /var/lib/postgres

Предоставлю права для записи:<br>
chmod 775 /var/lib/postgres


## Рзвернуть контейнер с PostgreSQL 15 смонтировав в него /var/lib/postgresql

Запускаю с параметрами:
- `-d`: Запуск в фоновом режиме.
  - `-v`: Монтирование каталога `/var/lib/postgres` в контейнер.
  - `-p`: Проброс порта `5432`.
  - `-e`: Переменные окружения (пользователь:posadmins пароль:PSpass1498e)

sudo docker run -d \ <br>
  --name postgres-server \ <br>
  -e POSTGRES_PASSWORD=PSpass1498e \ <br>
  -e POSTGRES_USER=posadmins \ <br>
  -v /var/lib/postgres:/var/lib/postgresql/data \ <br>
  -p 5432:5432 \ <br>
  postgres:15

  ## Развернуть контейнер с клиентом PostgreSQL

sudo docker run -it --rm \ <br>
  --name pg-client \ <br>
  --network host \ <br>
  postgres:15 \ <br>
  psql -h localhost -U posadmins<br>
![alt text](image-1.png)

## Подключится из контейнера с клиентом к контейнеру с сервером и сделать таблицу с парой строк

Подключаюсь из контейнера с клиентом к контейнеру с сервером PostgreSQL:<br>
sudo docker run -it --rm \ <br>
  --name pg-client \ <br>
  --network host \ <br>
  postgres:15 \ <br>
  psql -h localhost -U posadmins<br>

  Создаю таблицу test со следующими столбцами:<br>
  sql<br>
CREATE TABLE test <br>
( <br>
    Id SERIAL PRIMARY KEY, <br>
    FirstName CHARACTER VARYING(30), <br>
    LastName CHARACTER VARYING(30), <br>
    Email CHARACTER VARYING(30), <br>
    Age INTEGER <br>
  ); <br>

posadmins=# SELECT * FROM test;<br>
![alt text](image-2.png)

Заполняю таблицу данными:<br>
INSERT INTO test VALUES (1, 'Nik', 'Djonson', 'Nik.Djonson@test.ru', 55);<br>
INSERT INTO test VALUES (2, 'Max', 'Fire', 'Max.Fire@test.ru', 25);<br>
SELECT * FROM test;<br>
![alt text](image-3.png)


## Подключится к контейнеру с сервером с ноутбука/компьютера извне инстансов ЯО/места установки докера

Попробую подключиться к базе c другого ноутбука при помощи ПО DBeaver и проверить доступ к таблице test:<br>
![alt text](image-4.png)

Доступ есть, данные таблицы достцпны.

## Удаление и повторное создание контейнера c сервером PostgreSQL

Останавливаем и удаляем контейнер:<br>
sudo docker stop postgres-server<br>
sudo docker rm postgres-server<br>

Запускаем новый контейнер с темже каталогом данных:<br>
sudo docker run -d \ <br>
  --name postgres-server \ <br>
  -e POSTGRES_PASSWORD=PSpass1498e \ <br>
  -e POSTGRES_USER=posadmins \ <br>
  -v /var/lib/postgres:/var/lib/postgresql/data \ <br>
  -p 5432:5432 \ <br>
  postgres:15

  ## Проверка сохранности данных

  Подключаюсь через клиентский контейнер:<br>
  docker run -it --rm \ <br>
  --name pg-client \ <br>
  --network host \ <br>
  postgres:15 \ <br>
  psql -h localhost -U posadmins -c "SELECT * FROM test;" <br>
  ![alt text](image-5.png)

C другого ноутбука при помощи ПО DBeaver: <br>
![alt text](image-6.png)

**Итог:**
- Данные сохраняются благодаря монтированию тома `/var/lib/postgres` на хосте.<br>
- При пересоздании контейнера PostgreSQL использует существующие данные из этого каталога.