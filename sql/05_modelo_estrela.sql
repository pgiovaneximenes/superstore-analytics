-- 05_modelo_estrela.sql
-- Esquema estrela a partir de public.superstore_raw, no schema "dw".

DROP SCHEMA IF EXISTS dw CASCADE;
CREATE SCHEMA dw;

-- DIMENSÃO CLIENTE
-- Só atributos do cliente. Geografia fica fora de propósito: o mesmo
-- customer_id aparece com locais de entrega diferentes, e isso quebraria
-- a relação 1:N. Se customer_id tiver 2 nomes/segmentos, o INSERT abaixo
-- falha por violar a PK 

CREATE TABLE dw.dim_cliente (
    customer_id   TEXT PRIMARY KEY,
    customer_name TEXT NOT NULL,
    segment       TEXT NOT NULL
);

INSERT INTO dw.dim_cliente (customer_id, customer_name, segment)
SELECT DISTINCT customer_id, customer_name, segment
FROM public.superstore_raw;


-- DIMENSÃO PRODUTO (chave substituta)
-- product_id pode repetir com atributos diferentes; a chave substituta
-- produto_key garante uma linha única por combinação.

CREATE TABLE dw.dim_produto (
    produto_key  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id   TEXT NOT NULL,
    product_name TEXT NOT NULL,
    category     TEXT NOT NULL,
    sub_category TEXT NOT NULL,
    UNIQUE (product_id, product_name, category, sub_category)
);

INSERT INTO dw.dim_produto (product_id, product_name, category, sub_category)
SELECT DISTINCT product_id, product_name, category, sub_category
FROM public.superstore_raw
ORDER BY product_id, product_name;


-- DIMENSÃO LOCALIZAÇÃO (local de entrega da transação)

CREATE TABLE dw.dim_localizacao (
    localizacao_key INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country         TEXT NOT NULL,
    state           TEXT NOT NULL,
    city            TEXT NOT NULL,
    region          TEXT NOT NULL,
    market          TEXT NOT NULL,
    UNIQUE (country, state, city, region, market)
);

INSERT INTO dw.dim_localizacao (country, state, city, region, market)
SELECT DISTINCT country, state, city, region, market
FROM public.superstore_raw
ORDER BY market, country, state, city;


-- DIMENSÃO ENVIO (dimensão "junk": atributos de baixa cardinalidade
-- do pedido agrupados numa tabela pequena)

CREATE TABLE dw.dim_envio (
    envio_key      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ship_mode      TEXT NOT NULL,
    order_priority TEXT NOT NULL,
    UNIQUE (ship_mode, order_priority)
);

INSERT INTO dw.dim_envio (ship_mode, order_priority)
SELECT DISTINCT ship_mode, order_priority
FROM public.superstore_raw
ORDER BY ship_mode, order_priority;


-- DIMENSÃO DATA (calendário gerado; usada duas vezes na fato:
-- data do pedido e data de envio = "role-playing dimension")
-- Nomes em português definidos por array, para não depender do locale
-- do Windows/PostgreSQL.

CREATE TABLE dw.dim_data (
    data_key   INT PRIMARY KEY,          
    data       DATE NOT NULL UNIQUE,
    ano        SMALLINT NOT NULL,
    trimestre  SMALLINT NOT NULL,
    mes        SMALLINT NOT NULL,
    nome_mes   TEXT NOT NULL,
    ano_mes    TEXT NOT NULL,            
    dia_semana SMALLINT NOT NULL,       
    nome_dia   TEXT NOT NULL
);

INSERT INTO dw.dim_data
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,
    d::DATE,
    EXTRACT(YEAR    FROM d)::INT,
    EXTRACT(QUARTER FROM d)::INT,
    EXTRACT(MONTH   FROM d)::INT,
    (ARRAY['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho',
           'Agosto','Setembro','Outubro','Novembro','Dezembro'])[EXTRACT(MONTH FROM d)::INT],
    TO_CHAR(d, 'YYYY-MM'),
    EXTRACT(ISODOW FROM d)::INT,
    (ARRAY['Segunda-feira','Terça-feira','Quarta-feira','Quinta-feira',
           'Sexta-feira','Sábado','Domingo'])[EXTRACT(ISODOW FROM d)::INT]
FROM generate_series(
    (SELECT LEAST(MIN(order_date), MIN(ship_date))    FROM public.superstore_raw)::TIMESTAMP,
    (SELECT GREATEST(MAX(order_date), MAX(ship_date)) FROM public.superstore_raw)::TIMESTAMP,
    INTERVAL '1 day'
) AS g(d);


-- FATO VENDAS
-- order_id fica aqui como dimensão degenerada (identifica o pedido, mas
-- não tem atributos próprios que justifiquem uma tabela).
-- Tipos numéricos iguais aos da tabela raw.

CREATE TABLE dw.fato_vendas (
    row_id          INT PRIMARY KEY,
    order_id        TEXT NOT NULL,
    order_date_key  INT  NOT NULL REFERENCES dw.dim_data (data_key),
    ship_date_key   INT  NOT NULL REFERENCES dw.dim_data (data_key),
    customer_id     TEXT NOT NULL REFERENCES dw.dim_cliente (customer_id),
    produto_key     INT  NOT NULL REFERENCES dw.dim_produto (produto_key),
    localizacao_key INT  NOT NULL REFERENCES dw.dim_localizacao (localizacao_key),
    envio_key       INT  NOT NULL REFERENCES dw.dim_envio (envio_key),
    quantity        INT  NOT NULL,
    sales           NUMERIC(12,4) NOT NULL,
    discount        NUMERIC(5,4)  NOT NULL,
    profit          NUMERIC(12,4) NOT NULL,
    shipping_cost   NUMERIC(12,4) NOT NULL
);

-- LEFT JOIN + NOT NULL nas colunas de chave: se algum join não casar,
-- o INSERT falha com erro, em vez de descartar linhas em silêncio.
INSERT INTO dw.fato_vendas (
    row_id, order_id, order_date_key, ship_date_key, customer_id,
    produto_key, localizacao_key, envio_key,
    quantity, sales, discount, profit, shipping_cost
)
SELECT
    r.row_id,
    r.order_id,
    TO_CHAR(r.order_date, 'YYYYMMDD')::INT,
    TO_CHAR(r.ship_date,  'YYYYMMDD')::INT,
    r.customer_id,
    p.produto_key,
    l.localizacao_key,
    e.envio_key,
    r.quantity, r.sales, r.discount, r.profit, r.shipping_cost
FROM public.superstore_raw r
LEFT JOIN dw.dim_produto p
       ON  p.product_id   = r.product_id
       AND p.product_name = r.product_name
       AND p.category     = r.category
       AND p.sub_category = r.sub_category
LEFT JOIN dw.dim_localizacao l
       ON  l.country = r.country
       AND l.state   = r.state
       AND l.city    = r.city
       AND l.region  = r.region
       AND l.market  = r.market
LEFT JOIN dw.dim_envio e
       ON  e.ship_mode      = r.ship_mode
       AND e.order_priority = r.order_priority;