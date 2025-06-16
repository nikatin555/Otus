# 2. SQL и реляционные СУБД. Введение в PostgreSQL

# Домашнее задание

Работа с уровнями изоляции транзакции в PostgreSQL

**Цель:**

- научиться работать в Яндекс Облаке;
- научиться управлять уровнем изолции транзации в PostgreSQL и понимать особенность работы уровней read commited и repeatable read;

**Описание выполнения домашнего задания:**

   - создать новый проект в Яндекс облако или на любых ВМ, докере
   - далее создать инстанс виртуальной машины с дефолтными параметрами
   - добавить свой ssh ключ в metadata ВМ
   - зайти удаленным ssh (первая сессия), не забывайте про ssh-add
   - поставить PostgreSQL
   - зайти вторым ssh (вторая сессия)
   - запустить везде psql из под пользователя postgres
   - выключить auto commit
   - сделать в первой сессии новую таблицу и наполнить ее данными create table persons(id serial, first_name text, second_name text); insert into persons(first_name, second_name) values('ivan', 'ivanov'); insert into persons(first_name, second_name) values('petr', 'petrov'); commit;
   - посмотреть текущий уровень изоляции: show transaction isolation level
   - начать новую транзакцию в обоих сессиях с дефолтным (не меняя) уровнем изоляции
   - в первой сессии добавить новую запись insert into persons(first_name, second_name) values('sergey', 'sergeev');
   - сделать select from persons во второй сессии
   - видите ли вы новую запись и если да то почему?
   - завершить первую транзакцию - commit;
   - сделать select from persons во второй сессии
   - видите ли вы новую запись и если да то почему?
   - завершите транзакцию во второй сессии
   - начать новые но уже repeatable read транзации - set transaction isolation level repeatable read;
   - в первой сессии добавить новую запись insert into persons(first_name, second_name) values('sveta', 'svetova');
   - сделать select* from persons во второй сессии*
   - видите ли вы новую запись и если да то почему?
   - завершить первую транзакцию - commit;
   - сделать select from persons во второй сессии
   - видите ли вы новую запись и если да то почему?
   - завершить вторую транзакцию
   - сделать select * from persons во второй сессии
   - видите ли вы новую запись и если да то почему?

## создать ВМ с Ubuntu

Для выполнения ДЗ была выбрана более новая версия Ubuntu 24.04.2 LTS, установлена минимальная система на VM VirtualBox 7.1.8. SSH-ключ был сформирован при установке ОС.

Обновляем пакеты:<br>
sudo apt update && sudo apt upgrade -y

## Установите PostgreSQL 17

Добавьте репозиторий PostgreSQL и установим:<br>
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'<br>
wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/pgdg.asc<br>
sudo apt update<br>
sudo apt -y install postgresql-17

Проверим версию PostgreSQL:<br>
psql --version<br>
![alt text](image-2.png)

## Подготовка к эксперименту

Запустим psql в обоих сессиях:<br>
sudo -u postgres psql  <br>
![alt text](image-3.png)

# Уровень изоляции Read Committed (по умолчанию)

Отключим автокоммит (автоматическое сохранение изменений (autocommit) для текущей 1й сессии):<br>
\set AUTOCOMMIT off


## Сделать в первой сессии новую таблицу и наполнить ее данными

В первой сессии создаём таблицу и данные:

  CREATE TABLE persons(id serial, first_name text, second_name text); <br>
  INSERT INTO persons(first_name, second_name) VALUES('ivan', 'ivanov'); <br>
  INSERT INTO persons(first_name, second_name) VALUES('petr', 'petrov'); <br>
  COMMIT; <br>
![alt text](image-4.png)

## посмотреть текущий уровень изоляции: 

проверим уровень изоляции в обеих сессиях: <br>
postgres=!#  SHOW TRANSACTION ISOLATION LEVEL; <br>
![alt text](image-11.png) <br>
![alt text](image-12.png)

## Начать новую транзакцию в обоих сессиях с дефолтным (не меняя) уровнем изоляции

Дефолтный уровень:<br>
BEGIN; <br>

## В первой сессии добавить новую запись

В 1ю сессию добавляем: <br>
insert into persons(first_name, second_name) values('sergey', 'sergeev'); <br>

## сделать select from persons во второй сессии. Видите ли вы новую запись и если да то почему? <br>
postgres=#  SELECT * FROM persons; <br>
![alt text](image-9.png) <br>
Результат: видны только данные ivan и petr. <br>
Причина: незакоммиченные изменения не видны в read committed, п.э. новые записи не появились.

   ## Завершить первую транзакцию

   ![alt text](image-13.png)
   
   ## Cделать select from persons во второй сессии. Видите ли вы новую запись и если да то почему?

postgres=*# select * from persons; <br>
![alt text](image-14.png)

Результат: sergey появился.
Причина: после коммита изменения видны в read committed.

## завершите транзакцию во второй сессии

postgres=*# commit; <br>
![alt text](image-15.png)

# Уровень изоляции Repeatable Read

## Начнём новые транзакции с уровнем `repeatable read`.

Начнём новые, но уже repeatable read транзации - set transaction isolation level repeatable read: <br>
postgres=# BEGIN; <br>
  SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; <br>
![alt text](image-16.png) <br>
![alt text](image-17.png)

  ## В первой сессии добавить новую запись
  postgres=*# insert into persons(first_name, second_name) values('sveta', 'svetova'); <br>
![alt text](image-18.png)

 ## Cделать select* from persons во второй сессии. Видите ли вы новую запись, и если да то почему?

postgres=*# select * from persons;<br>
![alt text](image-19.png)<br> 
Результат: новую запись не видно. <br>
Причина: незакоммиченные изменения не видны , п.э. новые записи не появились.

## завершить первую транзакцию. Cделать select from persons во второй сессии. Видите ли вы новую запись и если да то почему?

postgres=*# commit; <br>
![alt text](image-20.png)

postgres=*# select * from persons; <br>
![alt text](image-21.png)

Результат:  новая запись sveta не видна. <br>
Причина: repeatable read использует снимок данных на момент начала транзакции.

# Завершить вторую транзакцию. Cделать select * from persons во второй сессии. Видите ли вы новую запись и если да то почему?

postgres=*# commit; <br>
![alt text](image-22.png) <br>
postgres=# select * from persons; <br>
![alt text](image-23.png) <br>
Результат: sveta теперь видна. <br>
Причина: транзакция завершена, запрос видит актуальные данные.

**Итог:**
| Действие                                         | Read Committed             | Repeatable Read             |
|--------------------------------------------------|----------------------------|-----------------------------|
| Видны незакоммиченные изменения?                 | ❌                         | ❌                          |
| Видны изменения после коммита в другой сессии?   | ✅ (сразу после коммита)   | ❌ (только после завершения текущей транзакции) |
| "Неповторяемое чтение" (non-repeatable read)     | Возможно                   | Невозможно                 |
| "Фантомное чтение" (phantom read)                | Возможно                   | Невозможно (в PostgreSQL)  |

- **Read Committed**: Изменения видны сразу после коммита в другой сессии.
- **Repeatable Read**: Гарантирует, что данные в течение транзакции остаются неизменными (снимок на момент `BEGIN`), новые строки от других транзакций не видны до завершения текущей транзакции.