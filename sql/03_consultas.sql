
-- Global Superstore — consultas analíticas
-- Base: superstore_raw (uma linha por ITEM de pedido, não por pedido).
-- Essa distinção importa: ~51 mil linhas correspondem a ~25 mil pedidos.



-- 1. Os 10 itens de maior valor unitário de venda
-- Cada linha é um item; order_id pode se repetir se dois itens caros estiverem no mesmo pedido.

SELECT
    order_id,
    customer_name,
    product_name,
    sales
FROM superstore_raw
ORDER BY sales DESC
LIMIT 10;


-- 1b. Os 10 PEDIDOS de maior faturamento
-- Versão agregada: soma os itens de cada pedido antes de ranquear.

SELECT
    order_id,
    customer_name,
    ROUND(SUM(sales), 2) AS faturamento,
    COUNT(*)             AS qtd_itens
FROM superstore_raw
GROUP BY order_id, customer_name
ORDER BY faturamento DESC
LIMIT 10;


-- 2. Quantos pedidos distintos existem na base?

SELECT COUNT(DISTINCT order_id) AS total_pedidos
FROM superstore_raw;



-- 3. Itens vendidos com prejuízo e desconto acima de 50%

SELECT
    order_id,
    product_name,
    sub_category,
    discount,
    sales,
    profit
FROM superstore_raw
WHERE profit   < 0
  AND discount > 0.5
ORDER BY profit;



-- 4. Faturamento e lucro por categoria

SELECT
    category,
    ROUND(SUM(sales),  2) AS faturamento,
    ROUND(SUM(profit), 2) AS lucro,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margem_pct
FROM superstore_raw
GROUP BY category
ORDER BY lucro DESC;



-- 5. Subcategorias com prejuízo consolidado
-- HAVING filtra DEPOIS da agregação — WHERE SUM(profit) < 0 daria erro.
-- Achado: apenas "Tables" opera no vermelho (~ -64 mil), puxado por desconto médio alto combinado com frete elevado.

SELECT
    sub_category,
    ROUND(SUM(profit), 2)    AS lucro,
    ROUND(AVG(discount), 4)  AS desconto_medio
FROM superstore_raw
GROUP BY sub_category
HAVING SUM(profit) < 0
ORDER BY lucro;



-- 6. Ticket médio por segmento de cliente
-- A subquery consolida os itens em pedido antes de tirar a média.
-- AVG(sales) direto na tabela daria a média por ITEM, não por pedido — números bem diferentes.

SELECT
    segment,
    COUNT(*)                      AS qtd_pedidos,
    ROUND(AVG(valor_pedido), 4)   AS ticket_medio
FROM (
    SELECT
        segment,
        order_id,
        SUM(sales) AS valor_pedido
    FROM superstore_raw
    GROUP BY segment, order_id
) AS pedidos
GROUP BY segment
ORDER BY ticket_medio DESC;



-- 7. Os 5 países de maior faturamento, entre os com mais de 100 pedidos

SELECT
    country,
    COUNT(DISTINCT order_id) AS qtd_pedidos,
    ROUND(SUM(sales), 2)     AS faturamento
FROM superstore_raw
GROUP BY country
HAVING COUNT(DISTINCT order_id) > 100
ORDER BY faturamento DESC
LIMIT 5;



-- 8. Faturamento por ano

SELECT
    EXTRACT(YEAR FROM order_date) AS ano,
    ROUND(SUM(sales),  2)         AS faturamento,
    ROUND(SUM(profit), 2)         AS lucro
FROM superstore_raw
GROUP BY ano
ORDER BY ano;


-- 9. Faturamento mensal de 2014
-- Filtro por intervalo (>= e <) em vez de EXTRACT(YEAR) = 2014: permite o uso do índice em order_date.
-- DATE_TRUNC preserva ano e mês juntos, então a ordenação cronológica sai de graça. O ::date remove a parte de hora e fuso.

SELECT
    DATE_TRUNC('month', order_date)::date AS mes,
    ROUND(SUM(sales), 2)                  AS faturamento
FROM superstore_raw
WHERE order_date >= '2014-01-01'
  AND order_date <  '2015-01-01'
GROUP BY mes
ORDER BY mes;



-- 10. Tempo médio de entrega por modalidade de envio
-- A subtração entre duas colunas date retorna inteiro de dias.

SELECT
    ship_mode,
    ROUND(AVG(ship_date - order_date), 2) AS dias_medios,
    COUNT(*)                              AS qtd_itens
FROM superstore_raw
GROUP BY ship_mode
ORDER BY dias_medios;
