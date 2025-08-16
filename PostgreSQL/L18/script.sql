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