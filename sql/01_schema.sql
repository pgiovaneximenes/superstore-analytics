-- =====================================================================
-- Global Superstore — criação da tabela bruta
-- =====================================================================
-- ATENÇÃO: este script apaga e recria a tabela. Rode apenas em uma
-- carga inicial ou quando precisar reimportar o CSV do zero.
--
-- Por que criar a tabela antes de importar:
-- o assistente do DBeaver infere os tipos a partir de uma amostra de
-- 100 linhas. Na primeira tentativa isso fez `sales` e `discount`
-- virarem integer, truncando todos os decimais. Definir o schema
-- manualmente evita o problema.
--
-- Por que numeric e não real/double para valores monetários:
-- ponto flutuante binário não representa decimais com exatidão. Somar
-- ~51 mil valores em float acumula erro de arredondamento e o total
-- diverge do valor real. Para dinheiro, numeric é o tipo correto.
-- =====================================================================

DROP TABLE IF EXISTS superstore_raw;

CREATE TABLE superstore_raw (
    row_id         integer,
    order_id       varchar(20),
    order_date     date,
    ship_date      date,
    ship_mode      varchar(30),
    customer_id    varchar(20),
    customer_name  varchar(100),
    segment        varchar(30),
    city           varchar(100),
    state          varchar(100),
    country        varchar(100),
    region         varchar(50),
    market         varchar(30),
    product_id     varchar(30),
    category       varchar(50),
    sub_category   varchar(50),
    product_name   varchar(255),
    sales          numeric(12,4),
    quantity       integer,
    discount       numeric(5,4),
    profit         numeric(12,4),
    shipping_cost  numeric(12,4),
    order_priority varchar(20)
);

