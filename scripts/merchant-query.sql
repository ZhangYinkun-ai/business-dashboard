-- ============================================================
-- 商家寄件业务数据查询 SQL
-- 使用方法：在 DataWorks 或 ODPS 控制台执行此 SQL
-- 将结果保存为 CSV/TSV 文件，用于更新 data.json
-- ============================================================

WITH daily_base AS (
SELECT
ds,
SUBSTR(ds, 1, 6) AS month_id,
CASE
WHEN t2.cp_name IS NULL OR t2.cp_name LIKE '%未知%' THEN '其他'
ELSE t2.cp_name
END AS carrier_name,
COUNT(1) AS order_cnt
FROM ttrl_cdm.v_dwd_rl_ord_gg_biz_flow_di_tagview t1
LEFT JOIN ascp_ads.dim_ascp_tb_return_cpcode_mapping t2
ON t1.task_excutor_cp_code = t2.cp_code
WHERE send_sub_type = '商家寄件'
AND is_test = 'N'
AND ds >= '20250701'
GROUP BY ds, SUBSTR(ds, 1, 6),
CASE
WHEN t2.cp_name IS NULL OR t2.cp_name LIKE '%未知%' THEN '其他'
ELSE t2.cp_name
END
),

-- FY26 (2025-07 ~ 2026-03) 服务商维度
fy26_cp AS (
SELECT
'FY26日均' AS metric_type,
carrier_name,
ROUND(SUM(order_cnt) * 1.0 / 274, 0) AS daily_avg
FROM daily_base
WHERE month_id >= '202507' AND month_id <= '202603'
GROUP BY carrier_name
),

-- 2026年各月 服务商维度
month_2026_cp AS (
SELECT
CONCAT(CAST(CAST(SUBSTR(month_id, 5, 2) AS INT) AS STRING), '月') AS metric_type,
carrier_name,
ROUND(SUM(order_cnt) * 1.0 /
CASE
WHEN month_id = TO_CHAR(GETDATE(), 'YYYYMM') THEN
CAST(TO_CHAR(DATEADD(GETDATE(), -1, 'DD'), 'DD') AS INT)
ELSE
DATEDIFF(
DATEADD(TO_DATE(CONCAT(month_id, '01'), 'YYYYMMDD'), 1, 'MM'),
TO_DATE(CONCAT(month_id, '01'), 'YYYYMMDD')
)
END, 0) AS daily_avg
FROM daily_base
WHERE month_id >= '202601'
GROUP BY month_id, carrier_name
),

-- T-1 服务商维度
t1_cp AS (
SELECT
'T-1' AS metric_type,
carrier_name,
SUM(order_cnt) AS daily_avg
FROM daily_base
WHERE ds = TO_CHAR(DATEADD(GETDATE(), -1, 'DD'), 'YYYYMMDD')
GROUP BY carrier_name
)

SELECT metric_type, carrier_name, daily_avg
FROM fy26_cp
UNION ALL
SELECT metric_type, carrier_name, daily_avg
FROM month_2026_cp
UNION ALL
SELECT metric_type, carrier_name, daily_avg
FROM t1_cp
ORDER BY carrier_name, metric_type
;
