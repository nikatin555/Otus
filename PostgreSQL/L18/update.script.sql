-- Создаем таблицу (если еще не создана)
CREATE TABLE IF NOT EXISTS good_sum_mart (
    good_name VARCHAR(255) PRIMARY KEY,
    sum_sale DECIMAL(15,2) NOT NULL
);

-- Создаем индекс для ускорения поиска
CREATE INDEX IF NOT EXISTS idx_good_sum_mart_name ON good_sum_mart(good_name);

-- Дополнительные индексы для связанных таблиц
CREATE INDEX IF NOT EXISTS idx_goods_id ON goods(goods_id);
CREATE INDEX IF NOT EXISTS idx_goods_name ON goods(good_name);
CREATE INDEX IF NOT EXISTS idx_sales_good_id ON sales(good_id);
CREATE INDEX IF NOT EXISTS idx_sales_qty ON sales(sales_qty);

-- Создаем функцию триггера
CREATE OR REPLACE FUNCTION update_good_sum_mart()
RETURNS TRIGGER AS $$
BEGIN
    -- Обработка операций DELETE
    IF (TG_OP = 'DELETE') THEN
        WITH price_info AS (
            SELECT good_name, good_price 
            FROM goods 
            WHERE goods_id = OLD.good_id
        )
        UPDATE good_sum_mart m
        SET sum_sale = sum_sale - (OLD.sales_qty * (SELECT good_price FROM price_info))
        WHERE m.good_name = (SELECT good_name FROM price_info);
        
        -- Удаляем записи с отрицательной суммой
        DELETE FROM good_sum_mart 
        WHERE sum_sale <= 0;
        
        RETURN OLD;
    
    -- Обработка операций INSERT и UPDATE
    ELSE
        -- Для INSERT используем NEW, для UPDATE вычисляем разницу
        WITH operation_data AS (
            SELECT 
                g.good_name,
                g.good_price,
                CASE 
                    WHEN TG_OP = 'INSERT' THEN NEW.sales_qty * g.good_price
                    WHEN TG_OP = 'UPDATE' AND OLD.good_id <> NEW.good_id THEN NEW.sales_qty * g.good_price
                    WHEN TG_OP = 'UPDATE' THEN (NEW.sales_qty - OLD.sales_qty) * g.good_price
                END as delta,
                CASE 
                    WHEN TG_OP = 'UPDATE' AND OLD.good_id <> NEW.good_id THEN OLD.good_id
                    ELSE NULL 
                END as old_good_id
            FROM goods g
            WHERE g.goods_id = CASE 
                WHEN TG_OP = 'INSERT' THEN NEW.good_id
                WHEN TG_OP = 'UPDATE' THEN NEW.good_id
            END
        ),
        -- Для случая смены товара в UPDATE обрабатываем старый товар
        old_good_data AS (
            SELECT 
                g.good_name,
                g.good_price,
                -OLD.sales_qty * g.good_price as delta
            FROM goods g
            WHERE TG_OP = 'UPDATE' 
                AND OLD.good_id <> NEW.good_id
                AND g.goods_id = OLD.good_id
        )
        -- Основной MERGE для нового товара
        INSERT INTO good_sum_mart (good_name, sum_sale)
        SELECT good_name, delta
        FROM operation_data
        ON CONFLICT (good_name) 
        DO UPDATE SET sum_sale = good_sum_mart.sum_sale + EXCLUDED.sum_sale;
        
        -- Дополнительный MERGE для старого товара при смене товара
        IF TG_OP = 'UPDATE' AND OLD.good_id <> NEW.good_id THEN
            INSERT INTO good_sum_mart (good_name, sum_sale)
            SELECT good_name, delta
            FROM old_good_data
            ON CONFLICT (good_name) 
            DO UPDATE SET sum_sale = good_sum_mart.sum_sale + EXCLUDED.sum_sale;
        END IF;
        
        RETURN CASE WHEN TG_OP = 'INSERT' THEN NEW ELSE NEW END;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер
CREATE TRIGGER sales_trigger
AFTER INSERT OR UPDATE OR DELETE ON sales
FOR EACH ROW EXECUTE FUNCTION update_good_sum_mart();