-- 04_diagnostico_modelo.sql
-- Rodar ANTES de 05_modelo_estrela.sql.
-- Objetivo: descobrir quais colunas identificam de fato cada entidade
-- (cliente, produto, local, pedido) antes de escolher chaves primárias.
-- Cada consulta abaixo diz qual resultado é o esperado.

-- 0. Confirma nomes e tipos das colunas (os scripts seguintes assumem estes nomes)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'superstore_raw'
ORDER BY ordinal_position;

-- 1. Grão: row_id identifica uma linha? (esperado: linhas = row_ids_distintos)
SELECT COUNT(*) AS linhas, COUNT(DISTINCT row_id) AS row_ids_distintos
FROM superstore_raw;

-- 2. customer_id tem um único nome e um único segmento? (esperado: 0 linhas)
--    Se retornar linhas, customer_id NÃO pode ser chave primária sozinho.
SELECT customer_id,
       COUNT(DISTINCT customer_name) AS nomes,
       COUNT(DISTINCT segment)       AS segmentos
FROM superstore_raw
GROUP BY customer_id
HAVING COUNT(DISTINCT customer_name) > 1
    OR COUNT(DISTINCT segment) > 1;

-- 3. A armadilha do README: clientes com mais de um local de entrega
--    (esperado: número > 0; é o motivo de geografia NÃO ficar na dim_cliente)
SELECT COUNT(*) AS clientes_com_varios_locais
FROM (
    SELECT customer_id
    FROM superstore_raw
    GROUP BY customer_id
    HAVING COUNT(DISTINCT (country, state, city)) > 1
) t;

-- 4. product_id tem um único nome/categoria/subcategoria? (esperado: 0 linhas;
--    se retornar linhas, a chave substituta da dim_produto é obrigatória)
SELECT product_id,
       COUNT(DISTINCT product_name) AS nomes,
       COUNT(DISTINCT category)     AS categorias,
       COUNT(DISTINCT sub_category) AS subcategorias
FROM superstore_raw
GROUP BY product_id
HAVING COUNT(DISTINCT product_name) > 1
    OR COUNT(DISTINCT category) > 1
    OR COUNT(DISTINCT sub_category) > 1;

-- 5. Atributos de pedido são consistentes dentro de um order_id? (esperado: 0 linhas)
--    Se sim, order_id pode ficar na fato como dimensão degenerada sem risco.
SELECT order_id
FROM superstore_raw
GROUP BY order_id
HAVING COUNT(DISTINCT order_date) > 1
    OR COUNT(DISTINCT customer_id) > 1
    OR COUNT(DISTINCT ship_mode) > 1;

-- 6. Nulos nas colunas que virarão dimensão (esperado: tudo 0)
--    O join da fato usa "=", que não casa NULL com NULL. Se houver nulos,
--    trocar por IS NOT DISTINCT FROM em 05_modelo_estrela.sql.
SELECT
    COUNT(*) FILTER (WHERE customer_id   IS NULL) AS customer_id,
    COUNT(*) FILTER (WHERE product_id    IS NULL) AS product_id,
    COUNT(*) FILTER (WHERE country       IS NULL) AS country,
    COUNT(*) FILTER (WHERE state         IS NULL) AS state,
    COUNT(*) FILTER (WHERE city          IS NULL) AS city,
    COUNT(*) FILTER (WHERE region        IS NULL) AS region,
    COUNT(*) FILTER (WHERE market        IS NULL) AS market,
    COUNT(*) FILTER (WHERE ship_mode     IS NULL) AS ship_mode,
    COUNT(*) FILTER (WHERE order_priority IS NULL) AS order_priority,
    COUNT(*) FILTER (WHERE order_date    IS NULL) AS order_date,
    COUNT(*) FILTER (WHERE ship_date     IS NULL) AS ship_date
FROM superstore_raw;