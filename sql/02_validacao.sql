-- =====================================================================
-- Global Superstore — validação pós-importação
-- =====================================================================
-- Rodar logo após a carga do CSV, antes de qualquer análise.
-- Se algum destes checks falhar, a análise em cima da base não vale.
-- =====================================================================


-- Check 1: os tipos ficaram como definidos no schema?
-- sales, profit, discount e shipping_cost devem ser numeric.
-- Se aparecer integer ou real, o assistente ignorou a tabela existente
-- e criou outra — refaça a importação mapeando com ESPAÇO.
SELECT
    ordinal_position,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'superstore_raw'
ORDER BY ordinal_position;


-- Check 2: os decimais sobreviveram?
-- Esperado: 0, 0.1, 0.15, 0.2, 0.3 ...
-- Se retornar apenas 0 e 1, discount foi truncado para integer.
SELECT DISTINCT discount
FROM superstore_raw
ORDER BY discount;


-- Check 3: o volume bate com o arquivo?
-- Esperado: ~51.290 linhas (varia entre versões do dataset).
SELECT COUNT(*) AS total_linhas
FROM superstore_raw;


-- Check 4: o período está completo?
-- Esperado: 2011 a 2014.
SELECT
    MIN(order_date) AS primeira_venda,
    MAX(order_date) AS ultima_venda
FROM superstore_raw;


-- Check 5: há datas nulas?
-- Importa porque AVG e subtração de datas ignoram NULL silenciosamente.
SELECT COUNT(*) AS registros_sem_data
FROM superstore_raw
WHERE order_date IS NULL
   OR ship_date IS NULL;


-- Check 6: quantas tabelas existem no schema?
-- Serve para detectar duplicatas criadas por importação mal mapeada.
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
