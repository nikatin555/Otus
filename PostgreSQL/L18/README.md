# 18. Хранимые функции и процедуры

## Домашнее задание

Триггеры, поддержка заполнения витрин

**Цель:**

Создать триггер для поддержки витрины в актуальном состоянии.

**Описание/Пошаговая инструкция выполнения домашнего задания:**

Скрипт и развернутое описание задачи – в ЛК (файл hw_triggers.sql) или по ссылке: https://disk.yandex.ru/d/l70AvknAepIJXQ

В БД создана структура, описывающая товары (таблица goods) и продажи (таблица sales).

Есть запрос для генерации отчета – сумма продаж по каждому товару.

БД была денормализована, создана таблица (витрина), структура которой повторяет структуру отчета.

Создать триггер на таблице продаж, для поддержки данных в витрине в актуальном состоянии (вычисляющий при каждой продаже сумму и записывающий её в витрину)

Подсказка: не забыть, что кроме INSERT есть еще UPDATE и DELETE

Задание со звездочкой*

Чем такая схема (витрина+триггер) предпочтительнее отчета, создаваемого "по требованию" (кроме производительности)? <br>
Подсказка: В реальной жизни возможны изменения цен.


# Решение по созданию триггера для поддержки витрины данных в PostgreSQL

## 1. Создание триггера для поддержки таблицы good_sum_mart

Решение для поддержки денормализованной таблицы good_sum_mart:

```sql
-- Создаем функцию триггера
CREATE OR REPLACE FUNCTION update_good_sum_mart()
RETURNS TRIGGER AS $$
BEGIN
    -- Обработка операций DELETE
    IF (TG_OP = 'DELETE') THEN
        UPDATE good_sum_mart m
        SET sum_sale = sum_sale - (OLD.sales_qty * (SELECT good_price FROM goods WHERE goods_id = OLD.good_id))
        WHERE m.good_name = (SELECT good_name FROM goods WHERE goods_id = OLD.good_id);
        
        -- Удаляем запись, если сумма продаж стала нулевой
        DELETE FROM good_sum_mart 
        WHERE good_name = (SELECT good_name FROM goods WHERE goods_id = OLD.good_id)
        AND sum_sale <= 0;
        
        RETURN OLD;
    
    -- Обработка операций INSERT
    ELSIF (TG_OP = 'INSERT') THEN
        -- Пытаемся обновить существующую запись
        UPDATE good_sum_mart m
        SET sum_sale = sum_sale + (NEW.sales_qty * (SELECT good_price FROM goods WHERE goods_id = NEW.good_id))
        WHERE m.good_name = (SELECT good_name FROM goods WHERE goods_id = NEW.good_id);
        
        -- Если записи не было, вставляем новую
        IF NOT FOUND THEN
            INSERT INTO good_sum_mart (good_name, sum_sale)
            SELECT good_name, (NEW.sales_qty * good_price)
            FROM goods WHERE goods_id = NEW.good_id;
        END IF;
        
        RETURN NEW;
    
    -- Обработка операций UPDATE
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Если изменился товар, обрабатываем как DELETE + INSERT
        IF OLD.good_id <> NEW.good_id THEN
            -- Уменьшаем сумму для старого товара
            UPDATE good_sum_mart m
            SET sum_sale = sum_sale - (OLD.sales_qty * (SELECT good_price FROM goods WHERE goods_id = OLD.good_id))
            WHERE m.good_name = (SELECT good_name FROM goods WHERE goods_id = OLD.good_id);
            
            -- Удаляем запись, если сумма продаж стала нулевой
            DELETE FROM good_sum_mart 
            WHERE good_name = (SELECT good_name FROM goods WHERE goods_id = OLD.good_id)
            AND sum_sale <= 0;
            
            -- Увеличиваем сумму для нового товара
            UPDATE good_sum_mart m
            SET sum_sale = sum_sale + (NEW.sales_qty * (SELECT good_price FROM goods WHERE goods_id = NEW.good_id))
            WHERE m.good_name = (SELECT good_name FROM goods WHERE goods_id = NEW.good_id);
            
            -- Если записи не было, вставляем новую
            IF NOT FOUND THEN
                INSERT INTO good_sum_mart (good_name, sum_sale)
                SELECT good_name, (NEW.sales_qty * good_price)
                FROM goods WHERE goods_id = NEW.good_id;
            END IF;
        ELSE
            -- Если товар не изменился, корректируем сумму на разницу
            UPDATE good_sum_mart m
            SET sum_sale = sum_sale + ((NEW.sales_qty - OLD.sales_qty) * (SELECT good_price FROM goods WHERE goods_id = NEW.good_id))
            WHERE m.good_name = (SELECT good_name FROM goods WHERE goods_id = NEW.good_id);
        END IF;
        
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер
CREATE TRIGGER sales_trigger
AFTER INSERT OR UPDATE OR DELETE ON sales
FOR EACH ROW EXECUTE FUNCTION update_good_sum_mart();

-- Инициализируем витрину текущими данными
INSERT INTO good_sum_mart (good_name, sum_sale)
SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name;
```

## 2. Ответ на вопрос со звездочкой*

Такая схема с витриной и триггером предпочтительнее отчета, создаваемого "по требованию", по нескольким причинам (кроме производительности):

1. **Консистентность данных при изменении цен**: Если цена товара изменится, витрина будет продолжать отражать исторические данные правильно (суммы продаж по старым ценам останутся неизменными). В отчете "по требованию" при изменении цены все исторические данные будут пересчитаны по новой цене, что может исказить реальную картину продаж.

2. **Историческая точность**: Витрина фиксирует суммы продаж на момент совершения продажи, что важно для финансовой отчетности. Отчет "по требованию" всегда будет показывать данные в текущих ценах.

3. **Уменьшение нагрузки в пиковые часы**: Вычисление агрегатов происходит в фоновом режиме в момент изменения данных, а не в момент запроса отчета, когда система может быть и так перегружена.

4. **Возможность сложной бизнес-логики**: В триггере можно реализовать более сложную логику обновления витрины, чем в простом агрегирующем запросе.

5. **Согласованность при параллельных операциях**: Триггер работает в рамках той же транзакции, что и изменение данных, что гарантирует согласованность данных даже при параллельных изменениях.


# Демонстрация работы триггера и сравнение подходов

## Демонстрация работы триггера

1. Сначала проверим текущее состояние витрины:

```sql
SELECT * FROM good_sum_mart;
```

Результат:
```sql
        good_name         |   sum_sale
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        65.50
(2 строки)

Время: 0,393 мс
```

2. Добавим новую продажу спичек:

```sql
INSERT INTO sales (good_id, sales_qty) VALUES (1, 10);
```

3. Проверим витрину снова:

```sql
SELECT * FROM good_sum_mart;
```
Результат:
```sql

        good_name         |   sum_sale
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        70.50
(2 строки)

Время: 0,324 мс
```

4. Обновим существующую продажу:

```sql
UPDATE sales SET sales_qty = 2 WHERE sales_id = 1;
```

5. Проверим витрину:

```sql
SELECT * FROM good_sum_mart;
```

Результат:
```sql
        good_name         |   sum_sale
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        66.50
(2 строки)

Время: 0,607 мс
```

6. Удалим одну из продаж:

```sql
DELETE FROM sales WHERE sales_id = 2;
```

7. Проверим витрину:

```sql
SELECT * FROM good_sum_mart;
```
Результат:
```sql
        good_name         |   sum_sale
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        66.00
(2 строки)

Время: 0,403 мс
```

## Демонстрация преимущества витрины перед отчетом "по требованию"

**Сценарий:** Изменение цены товара и сравнение результатов

1. Исходные данные:
```sql
SELECT * FROM goods WHERE goods_id = 1;
-- Цена спичек: 0.50

SELECT * FROM good_sum_mart WHERE good_name = 'Спички хозайственные';
-- Сумма продаж:

      good_name       | sum_sale
----------------------+----------
 Спички хозайственные |    66.00
(1 строка)

Время: 0,238 мс
```

2. Создадим отчет "по требованию":
```sql
SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
WHERE G.goods_id = 1
GROUP BY G.good_name;
```
Результат:
```sql
      good_name       |  sum
----------------------+-------
 Спички хозайственные | 66.00
(1 строка)

Время: 0,608 мс
```

3. Теперь изменим цену спичек:
```sql
UPDATE goods SET good_price = 0.75 WHERE goods_id = 1;
```

4. Сравним результаты:
   - Витрина (good_sum_mart) продолжает показывать старые суммы, рассчитанные по ценам на момент продажи
   - Отчет "по требованию" теперь показывает пересчитанные суммы по новой цене

```sql
-- Витрина (не изменилась):
SELECT * FROM good_sum_mart WHERE good_name = 'Спички хозайственные';
```
Результат:
```sql
postgres=# SELECT * FROM good_sum_mart WHERE good_name = 'Спички хозайственные';
      good_name       | sum_sale
----------------------+----------
 Спички хозайственные |    66.00
(1 строка)

Время: 0,906 мс
```
```sql
-- Отчет по требованию (изменился):
SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
WHERE G.goods_id = 1
GROUP BY G.good_name;
```
Результат:
```sql
      good_name       |  sum
----------------------+-------
 Спички хозайственные | 99.00
(1 строка)

Время: 1,083 мс
```

**Вывод:** Витрина сохраняет исторически точные данные о продажах по ценам, действовавшим на момент продажи, тогда как отчет "по требованию" пересчитывает все исторические данные по текущим ценам, что может искажать финансовую отчетность.

## Дополнительное преимущество: производительность при больших объемах данных

1. Добавим много данных для демонстрации:
```sql
INSERT INTO sales (good_id, sales_qty)
SELECT 1, (random() * 10 + 1)::int
FROM generate_series(1, 100000);
```

2. Замерим время выполнения:
   - Запрос к витрине выполняется мгновенно
   - Агрегирующий отчет требует значительного времени

```sql
-- Быстро (витрина):
EXPLAIN ANALYZE SELECT * FROM good_sum_mart;

                                                QUERY PLAN
-----------------------------------------------------------------------------------------------------------
 Seq Scan on good_sum_mart  (cost=0.00..1008.02 rows=2 width=47) (actual time=0.011..0.784 rows=2 loops=1)
 Planning Time: 0.222 ms
 Execution Time: 0.797 ms
(3 строки)

Время: 1,688 мс
```
```sql
-- Медленнее (отчет по требованию):
EXPLAIN ANALYZE 
SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name;
```
```sql
                                                        QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------
 HashAggregate  (cost=2921.69..2924.19 rows=200 width=176) (actual time=126.106..126.109 rows=2 loops=1)
   Group Key: g.good_name
   Batches: 1  Memory Usage: 40kB
   ->  Hash Join  (cost=19.45..1921.65 rows=100004 width=164) (actual time=0.060..52.142 rows=100004 loops=1)
         Hash Cond: (s.good_id = g.goods_id)
         ->  Seq Scan on sales s  (cost=0.00..1637.04 rows=100004 width=8) (actual time=0.038..10.286 rows=100004 loops=1)
         ->  Hash  (cost=14.20..14.20 rows=420 width=164) (actual time=0.014..0.014 rows=2 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 9kB
               ->  Seq Scan on goods g  (cost=0.00..14.20 rows=420 width=164) (actual time=0.007..0.009 rows=2 loops=1)
 Planning Time: 0.305 ms
 Execution Time: 126.153 ms
(11 строк)

Время: 127,273 мс
```

Эта демонстрация показывает, что витрина с триггером:
1. Сохраняет историческую точность данных
2. Обеспечивает стабильность отчетности при изменении цен
3. Обеспечивает высокую производительность
4. Гарантирует согласованность данных