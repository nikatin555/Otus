-- 1. Создание секционированной таблицы с улучшенной структурой
CREATE TABLE ticket_flights_partitioned (
    ticket_no character(13) NOT NULL,
    flight_id integer NOT NULL,
    fare_conditions character varying(10) NOT NULL,
    amount numeric(10,2) NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    PRIMARY KEY (ticket_no, flight_id, fare_conditions)
) PARTITION BY LIST (fare_conditions);

-- 2. Создание секций с индивидуальными настройками хранения
CREATE TABLE tf_economy PARTITION OF ticket_flights_partitioned
    FOR VALUES IN ('Economy')
    WITH (fillfactor = 90, autovacuum_enabled = true);
    
CREATE TABLE tf_comfort PARTITION OF ticket_flights_partitioned
    FOR VALUES IN ('Comfort')
    WITH (fillfactor = 85, autovacuum_enabled = true);
    
CREATE TABLE tf_business PARTITION OF ticket_flights_partitioned
    FOR VALUES IN ('Business')
    WITH (fillfactor = 80, autovacuum_enabled = true);

-- 3. Перенос данных с контролем прогресса
DO $$
DECLARE
    total_rows bigint;
    batch_size int := 100000;
    processed int := 0;
BEGIN
    SELECT COUNT(*) INTO total_rows FROM ticket_flights;
    
    RAISE NOTICE 'Начало переноса % строк', total_rows;
    
    WHILE processed < total_rows LOOP
        INSERT INTO ticket_flights_partitioned 
        SELECT * FROM ticket_flights
        ORDER BY flight_id
        LIMIT batch_size OFFSET processed;
        
        processed := processed + batch_size;
        RAISE NOTICE 'Перенесено % из % строк (%%)', 
            LEAST(processed, total_rows), 
            total_rows,
            ROUND(LEAST(processed, total_rows)::numeric / total_rows * 100, 2);
    END LOOP;
END $$;

-- 4. Создание оптимизированных индексов для каждой секции
-- Основные индексы для поиска
CREATE INDEX CONCURRENTLY idx_tf_economy_flight ON tf_economy (flight_id) 
    WITH (deduplicate_items = on);
CREATE INDEX CONCURRENTLY idx_tf_comfort_flight ON tf_comfort (flight_id)
    WITH (deduplicate_items = on);
CREATE INDEX CONCURRENTLY idx_tf_business_flight ON tf_business (flight_id)
    WITH (deduplicate_items = on);

-- Составные индексы для часто используемых запросов
CREATE INDEX CONCURRENTLY idx_tf_economy_combo ON tf_economy (flight_id, amount);
CREATE INDEX CONCURRENTLY idx_tf_comfort_combo ON tf_comfort (flight_id, amount);
CREATE INDEX CONCURRENTLY idx_tf_business_combo ON tb_business (flight_id, amount);

-- 5. Оптимизация для агрегатных запросов
-- Частичные индексы для отчетов
CREATE INDEX CONCURRENTLY idx_tf_economy_amount_high ON tf_economy (amount)
    WHERE amount > 10000;
    
CREATE INDEX CONCURRENTLY idx_tf_business_amount_low ON tf_business (amount)
    WHERE amount < 50000;

-- 6. Материализованные представления для аналитики
CREATE MATERIALIZED VIEW mv_flights_by_class AS
SELECT 
    fare_conditions,
    COUNT(*) as ticket_count,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount
FROM ticket_flights_partitioned
GROUP BY fare_conditions
WITH DATA;

-- 7. Автоматическое обновление представлений
CREATE OR REPLACE FUNCTION refresh_flight_views()
RETURNS TRIGGER AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_flights_by_class;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_refresh_views
AFTER INSERT OR UPDATE OR DELETE ON ticket_flights_partitioned
FOR EACH STATEMENT EXECUTE FUNCTION refresh_flight_views();

-- 8. Замена оригинальной таблицы с минимальным простоем
BEGIN;
    LOCK TABLE ticket_flights IN EXCLUSIVE MODE;
    
    -- Перенос ограничений (для внешних ключей)
    ALTER TABLE ticket_flights_partitioned 
        ADD CONSTRAINT fk_ticket_flights_tickets
        FOREIGN KEY (ticket_no) REFERENCES tickets(ticket_no);
    
    ALTER TABLE ticket_flights_partitioned
        ADD CONSTRAINT fk_ticket_flights_flights
        FOREIGN KEY (flight_id) REFERENCES flights(flight_id);
    
    -- Переключение таблиц
    ALTER TABLE ticket_flights RENAME TO ticket_flights_legacy;
    ALTER TABLE ticket_flights_partitioned RENAME TO ticket_flights;
    
    -- Перенос прав доступа
    GRANT ALL PRIVILEGES ON TABLE ticket_flights TO current_user;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO current_user;
    
    -- Создание представления для обратной совместимости
    CREATE VIEW ticket_flights_legacy_view AS 
    SELECT * FROM ticket_flights;
COMMIT;

-- 9. Оптимизация обслуживания
-- Настройка автоочистки для больших секций
ALTER TABLE tf_economy SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.02
);

-- 10. Функция для автоматического создания секций
CREATE OR REPLACE FUNCTION create_fare_condition_partition()
RETURNS TRIGGER AS $$
DECLARE
    partition_name text;
BEGIN
    partition_name := 'tf_' || LOWER(NEW.fare_conditions);
    
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF ticket_flights 
        FOR VALUES IN (%L)',
        partition_name, NEW.fare_conditions);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 11. Создание триггера для обработки новых классов
-- (актуально, если могут появиться новые fare_conditions)
CREATE TRIGGER trg_new_fare_condition
AFTER INSERT ON fare_conditions -- предположим, что есть справочник классов
FOR EACH ROW
EXECUTE FUNCTION create_fare_condition_partition();

-- 12. Завершающая оптимизация
ANALYZE ticket_flights;
VACUUM FULL VERBOSE ANALYZE ticket_flights;

-- 13. Проверка распределения данных
SELECT 
    fare_conditions,
    pg_size_pretty(pg_total_relation_size('tf_' || fare_conditions)) as partition_size,
    (SELECT COUNT(*) FROM ticket_flights WHERE fare_conditions = f.fare_conditions) as row_count
FROM (SELECT DISTINCT fare_conditions FROM ticket_flights) f;