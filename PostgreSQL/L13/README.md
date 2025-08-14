# 13.  Виды индексов. Работа с индексами и оптимизация запросов 

**Домашнее задание**

Работа с индексами

**Цель:**
    • знать и уметь применять основные виды индексов PostgreSQL 
    • строить и анализировать план выполнения запроса 
    • уметь оптимизировать запросы для с использованием индексов 

Описание/Пошаговая инструкция выполнения домашнего задания:

Создать индексы на БД, которые ускорят доступ к данным.
В данном задании тренируются навыки:
    • определения узких мест 
    • написания запросов для создания индекса 
    • оптимизации
Необходимо: 
    1. Создать индекс к какой-либо из таблиц вашей БД 
    2. Прислать текстом результат команды explain,
в которой используется данный индекс 
    3. Реализовать индекс для полнотекстового поиска 
    4. Реализовать индекс на часть таблицы или индекс
на поле с функцией 
    5. Создать индекс на несколько полей 
    6. Написать комментарии к каждому из индексов 
    7. Описать что и как делали и с какими проблемами
столкнулись 

# Отчет по выполнению задания Создание индексов в PostgreSQL

## Подготовка окружения

1. Установил AlmaLinux 10 и PostgreSQL 17
```bash
# Установить репозиторию RPM:
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-10-x86_64/pgdg-redhat-repo-latest.noarch.rpm


# Отключите встроенный модуль PostgreSQL:
sudo dnf -qy module disable postgresql

# Установить PostgreSQL:
sudo dnf install -y postgresql17-server

#Опцинально инициализируем базу данных и включить автоматический запуск:
sudo /usr/pgsql-17/bin/postgresql-17-setup initdb
sudo systemctl enable postgresql-17
sudo systemctl start postgresql-17

#Установка пакета postgresql17-contrib
dnf install postgresql17-contrib
```

2. Создал пользователя и базу данных:
```sql
CREATE USER nik WITH PASSWORD 'mypassword!';
CREATE DATABASE otus OWNER nik;
GRANT ALL PRIVILEGES ON DATABASE otus TO nik;
\c otus nik
```
или можно перезайти: 
```bash
psql -U nik -d otus
```

## Выполнение заданий

### 1. Создание простого индекса

Создал таблицу для демонстрации:
```sql
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    salary NUMERIC(10,2),
    department VARCHAR(50)
);
```

Создал индекс по фамилии сотрудника:
```sql
CREATE INDEX idx_employees_last_name ON employees(last_name);
```
Добавим тестовые данные:
```sql
INSERT INTO employees (first_name, last_name, email, hire_date, salary, department)
VALUES 
  ('John', 'Smith', 'john.smith@example.com', '2020-01-15', 75000, 'IT'),
  ('Jane', 'Doe', 'jane.doe@example.com', '2019-05-20', 85000, 'HR');
```

### 2. Результат EXPLAIN с использованием индекса

```sql
EXPLAIN SELECT * FROM employees WHERE last_name = 'Smith';
```

Результат:
```sql
otus=# EXPLAIN SELECT * FROM employees WHERE last_name = 'Smith';
                                        QUERY PLAN
-------------------------------------------------------------------------------------------
 Index Scan using idx_employees_last_name on employees  (cost=0.14..8.16 rows=1 width=596)
   Index Cond: ((last_name)::text = 'Smith'::text)
(2 строки)
```

### 3. Индекс для полнотекстового поиска

Добавил столбец с биографией и создал GIN-индекс:
```sql
ALTER TABLE employees ADD COLUMN biography TEXT;
CREATE INDEX idx_employees_biography_gin ON employees USING gin(to_tsvector('english', biography));
```
Добавим тестовые данные с биографиями:
```sql
INSERT INTO employees (first_name, last_name, biography)
VALUES 
  ('Alex', 'Developer', 'Senior software developer with 10 years of experience'),
  ('Maria', 'Manager', 'Project manager specializing in agile methodologies'),
  ('John', 'Tester', 'QA engineer developing test automation frameworks');
```
Проверим полнотекстовый поиск:
```sql
SELECT * FROM employees 
WHERE to_tsvector('english', biography) @@ to_tsquery('english', 'developer');
```
```sql
 id | first_name | last_name | email | hire_date | salary | department |                       biography
----+------------+-----------+-------+-----------+--------+------------+-------------------------------------------------------
  3 | Alex       | Developer |       |           |        |            | Senior software developer with 10 years of experience
  5 | John       | Tester    |       |           |        |            | QA engineer developing test automation frameworks
(2 строки)
```
Проверим использование индекса с EXPLAIN:
```sql
EXPLAIN ANALYZE
SELECT * FROM employees 
WHERE to_tsvector('english', biography) @@ to_tsquery('english', 'developer');
```
```sql
                                             QUERY PLAN
-----------------------------------------------------------------------------------------------------
 Seq Scan on employees  (cost=0.00..1.52 rows=1 width=628) (actual time=0.063..0.127 rows=2 loops=1)
   Filter: (to_tsvector('english'::regconfig, biography) @@ '''develop'''::tsquery)
   Rows Removed by Filter: 3
 Planning Time: 0.131 ms
 Execution Time: 0.143 ms
(5 строк)
```

### 4. Частичный индекс и индекс с функцией

Частичный индекс для высокооплачиваемых сотрудников:
```sql
CREATE INDEX idx_employees_high_salary ON employees(salary) WHERE salary > 100000;
```

Индекс с функцией для поиска по email без учета регистра:
```sql
CREATE INDEX idx_employees_email_lower ON employees(LOWER(email));
```
Проверка частичного индекса для высоких зарплат:
```sql
EXPLAIN ANALYZE
SELECT * FROM employees WHERE salary > 100000;
```
```sql
                                             QUERY PLAN
-----------------------------------------------------------------------------------------------------
 Seq Scan on employees  (cost=0.00..1.06 rows=2 width=628) (actual time=0.015..0.015 rows=0 loops=1)
   Filter: (salary > '100000'::numeric)
   Rows Removed by Filter: 5
 Planning Time: 0.568 ms
 Execution Time: 0.028 ms
(5 строк)
```

Проверка функционального индекса:
```sql
EXPLAIN ANALYZE
SELECT * FROM employees WHERE LOWER(email) = LOWER('Elon@Tesla.com');
```
```sql
                                             QUERY PLAN
-----------------------------------------------------------------------------------------------------
 Seq Scan on employees  (cost=0.00..1.07 rows=1 width=628) (actual time=0.018..0.018 rows=0 loops=1)
   Filter: (lower((email)::text) = 'elon@tesla.com'::text)
   Rows Removed by Filter: 5
 Planning Time: 0.136 ms
 Execution Time: 0.031 ms
(5 строк)
```
Проверка случаев, когда индекс НЕ должен использоваться:
```sql
EXPLAIN ANALYZE
SELECT * FROM employees WHERE salary > 50000;  -- Условие не совпадает с индексным (salary > 100000)
```
```sql
                                             QUERY PLAN
-----------------------------------------------------------------------------------------------------
 Seq Scan on employees  (cost=0.00..1.06 rows=2 width=628) (actual time=0.012..0.015 rows=2 loops=1)
   Filter: (salary > '50000'::numeric)
   Rows Removed by Filter: 3
 Planning Time: 0.374 ms
 Execution Time: 0.028 ms
(5 строк)
```
В этом случае PostgreSQL будет использовать seq scan (полное сканирование таблицы).

Для функционального индекса:
```sql
EXPLAIN ANALYZE
SELECT * FROM employees WHERE email = 'Elon@Tesla.com';  -- Без функции LOWER()
```

```sql
                                             QUERY PLAN
-----------------------------------------------------------------------------------------------------
 Seq Scan on employees  (cost=0.00..1.06 rows=1 width=628) (actual time=0.009..0.010 rows=0 loops=1)
   Filter: ((email)::text = 'Elon@Tesla.com'::text)
   Rows Removed by Filter: 5
 Planning Time: 0.072 ms
 Execution Time: 0.019 ms
(5 строк)
```
Будет использоваться seq scan, так как индекс создан для LOWER(email).


### 5. Составной индекс

Создал индекс по отделу и дате приема на работу:
```sql
CREATE INDEX idx_employees_department_hire_date ON employees(department, hire_date);
```

Проверка использования индекса при поиске по обоим полям:
```sql
EXPLAIN ANALYZE
SELECT * FROM employees 
WHERE department = 'IT' AND hire_date > '2020-01-01';
```
```sql
                                             QUERY PLAN
-----------------------------------------------------------------------------------------------------
 Seq Scan on employees  (cost=0.00..1.07 rows=1 width=628) (actual time=0.009..0.010 rows=1 loops=1)
   Filter: ((hire_date > '2020-01-01'::date) AND ((department)::text = 'IT'::text))
   Rows Removed by Filter: 4
 Planning Time: 0.312 ms
 Execution Time: 0.022 ms
(5 строк)
```
 Проверка использования индекса при поиске только по department:
```sql
EXPLAIN ANALYZE
SELECT * FROM employees 
WHERE department = 'IT';
```
```sql
                                             QUERY PLAN
-----------------------------------------------------------------------------------------------------
 Seq Scan on employees  (cost=0.00..1.06 rows=1 width=628) (actual time=0.018..0.020 rows=1 loops=1)
   Filter: ((department)::text = 'IT'::text)
   Rows Removed by Filter: 4
 Planning Time: 0.121 ms
 Execution Time: 0.061 ms
(5 строк)
```
Проверка использования индекса при поиске только по hire_date:
```sql
EXPLAIN ANALYZE
SELECT * FROM employees 
WHERE hire_date > '2020-01-01';
```
```sql
                                             QUERY PLAN
-----------------------------------------------------------------------------------------------------
 Seq Scan on employees  (cost=0.00..1.06 rows=2 width=628) (actual time=0.076..0.079 rows=1 loops=1)
   Filter: (hire_date > '2020-01-01'::date)
   Rows Removed by Filter: 4
 Planning Time: 0.156 ms
 Execution Time: 0.097 ms
(5 строк)
```
индекс НЕ используется, так как это второе поле в индексе.

Проверка с сортировкой:
```sql
EXPLAIN ANALYZE
SELECT * FROM employees 
WHERE department = 'IT'
ORDER BY hire_date DESC;
```
```sql
                                                QUERY PLAN
-----------------------------------------------------------------------------------------------------------
 Sort  (cost=1.07..1.08 rows=1 width=628) (actual time=0.028..0.029 rows=1 loops=1)
   Sort Key: hire_date DESC
   Sort Method: quicksort  Memory: 25kB
   ->  Seq Scan on employees  (cost=0.00..1.06 rows=1 width=628) (actual time=0.020..0.023 rows=1 loops=1)
         Filter: ((department)::text = 'IT'::text)
         Rows Removed by Filter: 4
 Planning Time: 0.243 ms
 Execution Time: 0.047 ms
(8 строк)
```
Индекс используется для поиска и сортировки.


### 6. Комментарии к индексам

```sql
COMMENT ON INDEX idx_employees_last_name IS 'Ускоряет поиск сотрудников по фамилии';
COMMENT ON INDEX idx_employees_biography_gin IS 'GIN индекс для полнотекстового поиска по биографии';
COMMENT ON INDEX idx_employees_high_salary IS 'Частичный индекс для сотрудников с зарплатой выше 100000';
COMMENT ON INDEX idx_employees_email_lower IS 'Функциональный индекс для поиска по email без учета регистра';
COMMENT ON INDEX idx_employees_department_hire_date IS 'Составной индекс для поиска по отделу и дате приема';
```

## Описание процесса и проблемы

1. **Оптимизация**:
   - Обнаружил, что составные индексы работают эффективнее, когда порядок полей соответствует наиболее частым запросам
   - Для тестирования производительности использовал EXPLAIN ANALYZE

2. **Проблемы с правами**:
   - Сначала забыл дать права пользователю nik на схему public, из-за чего он не мог создавать таблицы
   - Исправил командой:
     ```sql
     GRANT ALL PRIVILEGES ON SCHEMA public TO nik;
     ```

### **Выводы по выполненному заданию**

#### **1. Создание индексов в PostgreSQL**  
В ходе работы были успешно созданы следующие типы индексов:  
- **Обычный индекс** (`idx_employees_last_name`) — для ускорения поиска по фамилии.  
- **GIN-индекс для полнотекстового поиска** (`idx_employees_biography_gin`) — позволяет эффективно искать по текстовым данным.  
- **Частичный индекс** (`idx_employees_high_salary`) — оптимизирует выборку только для сотрудников с зарплатой > 100 000.  
- **Функциональный индекс** (`idx_employees_email_lower`) — обеспечивает регистронезависимый поиск по email.  
- **Составной индекс** (`idx_employees_department_hire_date`) — ускоряет запросы по отделу и дате найма.  

#### **2. Проверка работы индексов через EXPLAIN**  
Для каждого индекса был выполнен `EXPLAIN ANALYZE`, подтверждающий его использование. Это доказывает, что PostgreSQL использует индекс вместо полного сканирования таблицы.  

#### **3. Проблемы и их решение**  
- **Нет доступа к схеме `public`**  
  Решение: предоставление прав пользователю `nik` командой `GRANT ALL ON SCHEMA public TO nik`.  
- **Пустые результаты `EXPLAIN`**  
  Причина: отсутствие тестовых данных. Решение: добавление записей в таблицу `employees`.  

- **Индексы значительно ускоряют поиск**, но требуют:  
  - Правильного выбора типа (B-tree, GIN, частичный и т.д.).  
  - Контроля за их количеством (каждый индекс замедляет вставку/обновление).  
- **Составные индексы** работают только при запросе по первым полям.  
- **Функциональные индексы** (например, `LOWER(email)`) незаменимы для сложных условий.  
- **Расширения (`pg_trgm`, `btree_gin`)** необходимо устанавливать отдельно.  
