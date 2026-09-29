-- Global Superstore — consultas analíticas sobre o modelo estrela
-- Base: schema dw (fato_vendas + dimensões). Cada linha da fato é um ITEM de pedido.
-- Mesmas perguntas e mesmas colunas de saída de 03_consultas.sql (tabela bruta);
-- muda apenas a origem dos dados: métricas vêm da fato, atributos vêm das dimensões.

-- 1. Os 10 itens de maior valor unitário de venda
-- Cada linha é um item; order_id pode se repetir se dois itens caros estiverem no mesmo pedido.

SELECT
    f.order_id,
    c.customer_name,
    p.product_name,
    f.sales
FROM dw.fato_vendas f
JOIN dw.dim_cliente c ON c.customer_id = f.customer_id
JOIN dw.dim_produto p ON p.produto_key = f.produto_key
ORDER BY f.sales DESC
LIMIT 10;


-- 1b. Os 10 PEDIDOS de maior faturamento

SELECT
    f.order_id,
    c.customer_name,
    ROUND(SUM(f.sales), 2) AS faturamento,
    COUNT(*)               AS qtd_itens
FROM dw.fato_vendas f
JOIN dw.dim_cliente c ON c.customer_id = f.customer_id
GROUP BY f.order_id, c.customer_name
ORDER BY faturamento DESC
LIMIT 10;


-- 2. Quantos pedidos distintos existem na base?

SELECT COUNT(DISTINCT order_id) AS total_pedidos
FROM dw.fato_vendas;



-- 3. Itens vendidos com prejuízo e desconto acima de 50%

SELECT
    f.order_id,
    p.product_name,
    p.sub_category,
    f.discount,
    f.sales,
    f.profit
FROM dw.fato_vendas f
JOIN dw.dim_produto p ON p.produto_key = f.produto_key
WHERE f.profit   < 0
  AND f.discount > 0.5
ORDER BY f.profit;



-- 4. Faturamento e lucro por categoria

SELECT
    p.category,
    ROUND(SUM(f.sales),  2) AS faturamento,
    ROUND(SUM(f.profit), 2) AS lucro,
    ROUND(SUM(f.profit) / SUM(f.sales) * 100, 2) AS margem_pct
FROM dw.fato_vendas f
JOIN dw.dim_produto p ON p.produto_key = f.produto_key
GROUP BY p.category
ORDER BY lucro DESC;



-- 5. Subcategorias com prejuízo consolidado
-- HAVING filtra DEPOIS da agregação — WHERE SUM(profit) < 0 daria erro.

SELECT
    p.sub_category,
    ROUND(SUM(f.profit), 2)    AS lucro,
    ROUND(AVG(f.discount), 4)  AS desconto_medio
FROM dw.fato_vendas f
JOIN dw.dim_produto p ON p.produto_key = f.produto_key
GROUP BY p.sub_category
HAVING SUM(f.profit) < 0
ORDER BY lucro;



-- 6. Ticket médio por segmento de cliente

SELECT
    segment,
    COUNT(*)                      AS qtd_pedidos,
    ROUND(AVG(valor_pedido), 4)   AS ticket_medio
FROM (
    SELECT
        c.segment,
        f.order_id,
        SUM(f.sales) AS valor_pedido
    FROM dw.fato_vendas f
    JOIN dw.dim_cliente c ON c.customer_id = f.customer_id
    GROUP BY c.segment, f.order_id
) AS pedidos
GROUP BY segment
ORDER BY ticket_medio DESC;



-- 7. Os 5 países de maior faturamento, entre os com mais de 100 pedidos

SELECT
    l.country,
    COUNT(DISTINCT f.order_id) AS qtd_pedidos,
    ROUND(SUM(f.sales), 2)     AS faturamento
FROM dw.fato_vendas f
JOIN dw.dim_localizacao l ON l.localizacao_key = f.localizacao_key
GROUP BY l.country
HAVING COUNT(DISTINCT f.order_id) > 100
ORDER BY faturamento DESC
LIMIT 5;



-- 8. Faturamento por ano

SELECT
    d.ano,
    ROUND(SUM(f.sales),  2) AS faturamento,
    ROUND(SUM(f.profit), 2) AS lucro
FROM dw.fato_vendas f
JOIN dw.dim_data d ON d.data_key = f.order_date_key
GROUP BY d.ano
ORDER BY d.ano;


-- 9. Faturamento mensal de 2014
-- O filtro incide sobre a dimensão (dim_data, poucos milhares de linhas) e a fato é alcançada pelo join. 
-- DATE_TRUNC mantém a coluna "mes" como data (1º dia do mês), igual à versão bruta.

SELECT
    DATE_TRUNC('month', d.data)::date AS mes,
    ROUND(SUM(f.sales), 2)            AS faturamento
FROM dw.fato_vendas f
JOIN dw.dim_data d ON d.data_key = f.order_date_key
WHERE d.ano = 2014
GROUP BY DATE_TRUNC('month', d.data)::date
ORDER BY mes;


-- 10. Tempo médio de entrega por modalidade de envio
-- dim_data é usada duas vezes (data do pedido e data de envio): role-playing dimension.
-- A subtração entre duas colunas date retorna inteiro de dias.

SELECT
    e.ship_mode,
    ROUND(AVG(ds.data - dp.data), 2) AS dias_medios,
    COUNT(*)                         AS qtd_itens
FROM dw.fato_vendas f
JOIN dw.dim_envio e  ON e.envio_key = f.envio_key
JOIN dw.dim_data  dp ON dp.data_key = f.order_date_key
JOIN dw.dim_data  ds ON ds.data_key = f.ship_date_key
GROUP BY e.ship_mode
ORDER BY dias_medios;


