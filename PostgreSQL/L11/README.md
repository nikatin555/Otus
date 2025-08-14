# 11.  Выборка данных, виды join'ов. Применение и оптимизация. 

## Домашнее задание

Работа с join'ами, статистикой

**Цель:**

- знать и уметь применять различные виды join'ов
- строить и анализировать план выполенения запроса
- оптимизировать запрос
- уметь собирать и анализировать статистику для таблицы

**Описание/Пошаговая инструкция выполнения домашнего задания:**

В результате выполнения ДЗ вы научитесь пользоваться
различными вариантами соединения таблиц.
В данном задании тренируются навыки:

    - написания запросов с различными типами соединений
    Необходимо:

    1. Реализовать прямое соединение двух или более таблиц
    2. Реализовать левостороннее (или правостороннее) соединение двух или более таблиц
    3. Реализовать кросс соединение двух или более таблиц
    4. Реализовать полное соединение двух или более таблиц
    5. Реализовать запрос, в котором будут использованы
    разные типы соединений
    6. Сделать комментарии на каждый запрос
    7. К работе приложить структуру таблиц, для которых
    выполнялись соединения

8. Задание со звездочкой*
Придумайте 3 своих метрики на основе показанных представлений, отправьте их через ЛК.

## Подготовка: Установка и настройка PostgreSQL на AlmaLinux 10

## Установка PostgreSQL

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
```


# Структура таблиц для примеров запросов

```sql
-- Создание таблиц
CREATE TABLE departments (
    department_id SERIAL PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100)
);

CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    hire_date DATE NOT NULL,
    department_id INT REFERENCES departments(department_id),
    salary DECIMAL(10, 2)
);

CREATE TABLE projects (
    project_id SERIAL PRIMARY KEY,
    project_name VARCHAR(100) NOT NULL,
    budget DECIMAL(15, 2),
    start_date DATE,
    end_date DATE
);

CREATE TABLE employee_projects (
    employee_id INT REFERENCES employees(employee_id),
    project_id INT REFERENCES projects(project_id),
    hours_worked DECIMAL(5, 2),
    PRIMARY KEY (employee_id, project_id)
);

-- Заполнение тестовыми данными
INSERT INTO departments (department_name, location) VALUES 
('IT', 'Floor 1'),
('Marketing', 'Floor 2'),
('Finance', 'Floor 3'),
('HR', 'Floor 1'),
('Operations', 'Floor 4');

INSERT INTO employees (first_name, last_name, email, hire_date, department_id, salary) VALUES 
('John', 'Doe', 'john.doe@example.com', '2020-01-15', 1, 75000),
('Jane', 'Smith', 'jane.smith@example.com', '2019-05-20', 2, 68000),
('Robert', 'Johnson', 'robert.johnson@example.com', '2021-03-10', 1, 82000),
('Emily', 'Davis', 'emily.davis@example.com', '2018-11-05', 3, 90000),
('Michael', 'Wilson', 'michael.wilson@example.com', '2022-02-18', NULL, 60000);

INSERT INTO projects (project_name, budget, start_date, end_date) VALUES 
('Website Redesign', 50000, '2023-01-10', '2023-06-30'),
('Marketing Campaign', 75000, '2023-02-15', '2023-12-31'),
('Financial System Upgrade', 120000, '2023-03-01', '2024-03-01'),
('HR Portal', 30000, '2023-04-01', '2023-09-30');

INSERT INTO employee_projects (employee_id, project_id, hours_worked) VALUES 
(1, 1, 120.5),
(1, 3, 80.0),
(2, 2, 150.0),
(3, 1, 90.0),
(3, 3, 110.0),
(4, 3, 75.5),
(4, 4, 60.0);
```

# Примеры запросов с различными типами соединений

## 1. Прямое соединение (INNER JOIN)

```sql
-- Получаем список сотрудников с указанием их отдела
SELECT e.first_name, e.last_name, d.department_name
FROM employees e
INNER JOIN departments d ON e.department_id = d.department_id;

-- Комментарий: INNER JOIN возвращает только те строки, где есть соответствие в обеих таблицах.
-- Сотрудники без отдела (department_id IS NULL) не будут включены в результат.
```
```sql
 first_name | last_name | department_name
------------+-----------+-----------------
 John       | Doe       | IT
 Jane       | Smith     | Marketing
 Robert     | Johnson   | IT
 Emily      | Davis     | Finance
(4 строки)
```
## 2. Левостороннее соединение (LEFT JOIN)

```sql
-- Получаем все отделы и сотрудников в них, включая отделы без сотрудников
SELECT d.department_name, e.first_name, e.last_name
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id
ORDER BY d.department_name;

-- Комментарий: LEFT JOIN возвращает все строки из левой таблицы (departments), даже если нет соответствия в правой (employees).
-- Для отделов без сотрудников поля из таблицы employees будут NULL.
```
```sql
 department_name | first_name | last_name
-----------------+------------+-----------
 Finance         | Emily      | Davis
 HR              |            |
 IT              | John       | Doe
 IT              | Robert     | Johnson
 Marketing       | Jane       | Smith
 Operations      |            |
(6 строк)
```
## 3. Кросс соединение (CROSS JOIN)

```sql
-- Создаем все возможные комбинации сотрудников и проектов
SELECT e.first_name, e.last_name, p.project_name
FROM employees e
CROSS JOIN projects p;

-- Комментарий: CROSS JOIN создает декартово произведение строк из обеих таблиц.
-- Количество строк в результате равно произведению количества строк в таблицах.
-- В реальных задачах используется редко, но может быть полезен для генерации тестовых данных.
```
```sql
first_name | last_name |       project_name
------------+-----------+--------------------------
 John       | Doe       | Website Redesign
 Jane       | Smith     | Website Redesign
 Robert     | Johnson   | Website Redesign
 Emily      | Davis     | Website Redesign
 Michael    | Wilson    | Website Redesign
 John       | Doe       | Marketing Campaign
 Jane       | Smith     | Marketing Campaign
 Robert     | Johnson   | Marketing Campaign
 Emily      | Davis     | Marketing Campaign
 Michael    | Wilson    | Marketing Campaign
 John       | Doe       | Financial System Upgrade
 Jane       | Smith     | Financial System Upgrade
 Robert     | Johnson   | Financial System Upgrade
 Emily      | Davis     | Financial System Upgrade
 Michael    | Wilson    | Financial System Upgrade
 John       | Doe       | HR Portal
 Jane       | Smith     | HR Portal
 Robert     | Johnson   | HR Portal
 Emily      | Davis     | HR Portal
 Michael    | Wilson    | HR Portal
(20 строк)
```

## 4. Полное соединение (FULL OUTER JOIN)

```sql
-- Получаем все сочетания сотрудников и проектов, включая сотрудников без проектов и проекты без сотрудников
SELECT e.first_name, e.last_name, p.project_name, ep.hours_worked
FROM employees e
FULL OUTER JOIN employee_projects ep ON e.employee_id = ep.employee_id
FULL OUTER JOIN projects p ON ep.project_id = p.project_id;

-- Комментарий: FULL OUTER JOIN возвращает все строки из обеих таблиц, с NULL значениями там, где нет соответствия.
-- Полезен для выявления "одиноких" записей в обеих таблицах.
```
```sql
 first_name | last_name |       project_name       | hours_worked
------------+-----------+--------------------------+--------------
 John       | Doe       | Website Redesign         |       120.50
 John       | Doe       | Financial System Upgrade |        80.00
 Jane       | Smith     | Marketing Campaign       |       150.00
 Robert     | Johnson   | Website Redesign         |        90.00
 Robert     | Johnson   | Financial System Upgrade |       110.00
 Emily      | Davis     | Financial System Upgrade |        75.50
 Emily      | Davis     | HR Portal                |        60.00
 Michael    | Wilson    |                          |
(8 строк)
```

## 5. Запрос с разными типами соединений

```sql
-- Получаем информацию о сотрудниках, их отделах и проектах
SELECT 
    d.department_name,
    e.first_name, 
    e.last_name,
    p.project_name,
    ep.hours_worked,
    (ep.hours_worked * e.salary / 160) AS project_cost_estimate
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id
LEFT JOIN employee_projects ep ON e.employee_id = ep.employee_id
LEFT JOIN projects p ON ep.project_id = p.project_id
ORDER BY d.department_name, e.last_name, p.project_name;

-- Комментарий: В этом запросе используется цепочка LEFT JOIN для сохранения всех отделов,
-- даже если в них нет сотрудников или сотрудники не работают над проектами.
-- Также рассчитывается примерная стоимость участия сотрудника в проекте на основе его зарплаты.
```
```sql
department_name | first_name | last_name |       project_name       | hours_worked | project_cost_estimate
-----------------+------------+-----------+--------------------------+--------------+-----------------------
 Finance         | Emily      | Davis     | Financial System Upgrade |        75.50 |    42468.750000000000
 Finance         | Emily      | Davis     | HR Portal                |        60.00 |    33750.000000000000
 HR              |            |           |                          |              |
 IT              | John       | Doe       | Financial System Upgrade |        80.00 |    37500.000000000000
 IT              | John       | Doe       | Website Redesign         |       120.50 |    56484.375000000000
 IT              | Robert     | Johnson   | Financial System Upgrade |       110.00 |    56375.000000000000
 IT              | Robert     | Johnson   | Website Redesign         |        90.00 |    46125.000000000000
 Marketing       | Jane       | Smith     | Marketing Campaign       |       150.00 |    63750.000000000000
 Operations      |            |           |                          |              |
(9 строк)
```

# Задание со звездочкой: 3 собственные метрики


1. Метрика: Загрузка отделов (среднее количество проектов на сотрудника)
```sql
SELECT 
    d.department_name,
    COUNT(DISTINCT e.employee_id) AS employee_count,
    COUNT(DISTINCT ep.project_id) AS project_count,
    ROUND(COUNT(DISTINCT ep.project_id)::DECIMAL / NULLIF(COUNT(DISTINCT e.employee_id), 0), 2) AS projects_per_employee
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id
LEFT JOIN employee_projects ep ON e.employee_id = ep.employee_id
GROUP BY d.department_name;
```
```sql
 department_name | employee_count | project_count | projects_per_employee
-----------------+----------------+---------------+-----------------------
 Finance         |              1 |             2 |                  2.00
 HR              |              0 |             0 |
 IT              |              2 |             2 |                  1.00
 Marketing       |              1 |             1 |                  1.00
 Operations      |              0 |             0 |
(5 строк)
```
 2. Метрика: Эффективность проекта (отношение бюджета к фактическим трудозатратам)
```sql
SELECT 
    p.project_name,
    p.budget,
    SUM(ep.hours_worked * e.salary / 160) AS estimated_cost,
    ROUND((SUM(ep.hours_worked * e.salary / 160) / p.budget * 100), 2) AS cost_percentage_of_budget
FROM projects p
LEFT JOIN employee_projects ep ON p.project_id = ep.project_id
LEFT JOIN employees e ON ep.employee_id = e.employee_id
GROUP BY p.project_id
ORDER BY cost_percentage_of_budget DESC;
```
```sql
       project_name       |  budget   |   estimated_cost    | cost_percentage_of_budget
--------------------------+-----------+---------------------+---------------------------
 Website Redesign         |  50000.00 | 102609.375000000000 |                    205.22
 Financial System Upgrade | 120000.00 | 136343.750000000000 |                    113.62
 HR Portal                |  30000.00 |  33750.000000000000 |                    112.50
 Marketing Campaign       |  75000.00 |  63750.000000000000 |                     85.00
(4 строки)
```

3. Метрика: Сравнение зарплат между отделами
```sql
SELECT 
    d.department_name,
    COUNT(e.employee_id) AS employee_count,
    ROUND(AVG(e.salary), 2) AS avg_salary,
    MIN(e.salary) AS min_salary,
    MAX(e.salary) AS max_salary,
    ROUND((MAX(e.salary) - MIN(e.salary)) / AVG(e.salary) * 100, 2) AS salary_range_percentage
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id
GROUP BY d.department_name
HAVING COUNT(e.employee_id) > 0
ORDER BY avg_salary DESC;
```
```sql
 department_name | employee_count | avg_salary | min_salary | max_salary | salary_range_percentage
-----------------+----------------+------------+------------+------------+-------------------------
 Finance         |              1 |   90000.00 |   90000.00 |   90000.00 |                    0.00
 IT              |              2 |   78500.00 |   75000.00 |   82000.00 |                    8.92
 Marketing       |              1 |   68000.00 |   68000.00 |   68000.00 |                    0.00
(3 строки)
```

### **Вывод**

## **Реализация SQL-запросов с разными типами соединений**  

### **1. Прямое соединение (INNER JOIN)**  
Возвращает только сотрудников, у которых указан отдел (исключает `NULL`).  

### **2. Левостороннее соединение (LEFT JOIN)**  
Показывает все отделы, даже если в них нет сотрудников (поля `employees` будут `NULL`).  

### **3. Кросс-соединение (CROSS JOIN)**  
Создает все возможные комбинации сотрудников и проектов (декартово произведение).  

### **4. Полное соединение (FULL OUTER JOIN)**  
Включает всех сотрудников (даже без проектов) и все проекты (даже без сотрудников).  

### **5. Комбинированный запрос (разные JOIN)**  
Объединяет данные по отделам, сотрудникам и проектам, сохраняя все отделы.  

## **Дополнительные метрики (задание со звёздочкой)**  
1. **Загрузка отделов** (среднее количество проектов на сотрудника).  
2. **Эффективность проекта** (отношение бюджета к трудозатратам).  
3. **Сравнение зарплат** между отделами (мин/макс/разброс).  

  
✅ **PostgreSQL 17 успешно настроен** и протестирован на AlmaLinux 10.  
✅ **Реализованы все типы соединений** (INNER, LEFT, CROSS, FULL) с пояснениями.  
✅ **Разработаны 3 аналитические метрики** для оценки данных.  

