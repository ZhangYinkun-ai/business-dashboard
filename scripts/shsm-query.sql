WITH base AS (
  SELECT
    ds,
    std_company_name,
    sub_trade_id
  FROM ascp_ads.ads_ascp_ffl_shsm_sign_detail_di
  WHERE is_should_fulfil = 1
    AND ffl_deliver_result = 'TO_HOME'
    AND std_company_name IN ('中通', '圆通', '申通', '韵达', '极兔速递', '顺丰', '丹鸟')
),
company_daily AS (
  SELECT
    ds,
    std_company_name AS company_group,
    COUNT(DISTINCT sub_trade_id) AS order_cnt
  FROM base
  GROUP BY ds, std_company_name
),
summary_daily AS (
  SELECT
    ds,
    '汇总（中通/圆通/申通/韵达/极兔）' AS company_group,
    COUNT(DISTINCT sub_trade_id) AS order_cnt
  FROM base
  WHERE std_company_name IN ('中通', '圆通', '申通', '韵达', '极兔速递')
  GROUP BY ds
),
all_daily AS (
  SELECT
    ds,
    company_group,
    order_cnt,
    MAX(ds) OVER () AS max_ds
  FROM (
    SELECT * FROM company_daily
    UNION ALL
    SELECT * FROM summary_daily
  ) t
),
fy26 AS (
  SELECT
    company_group,
    'FY26日均(单)' AS metric,
    ROUND(SUM(order_cnt) * 1.0 / COUNT(DISTINCT ds), 0) AS val
  FROM all_daily
  WHERE ds BETWEEN '20250401' AND '20260331'
  GROUP BY company_group
),
monthly AS (
  SELECT
    company_group,
    CONCAT(SUBSTRING(ds, 1, 6), '日均(单)') AS metric,
    ROUND(SUM(order_cnt) * 1.0 / COUNT(DISTINCT ds), 0) AS val
  FROM all_daily
  WHERE ds >= '20260101'
    AND ds < CONCAT(SUBSTRING(max_ds, 1, 6), '01')
  GROUP BY company_group, SUBSTRING(ds, 1, 6)
),
current_month AS (
  SELECT
    company_group,
    CONCAT(SUBSTRING(max_ds, 1, 6), '截至T-1日均(单)') AS metric,
    ROUND(SUM(order_cnt) * 1.0 / COUNT(DISTINCT ds), 0) AS val
  FROM all_daily
  WHERE ds >= CONCAT(SUBSTRING(max_ds, 1, 6), '01')
    AND ds <= max_ds
  GROUP BY company_group, SUBSTRING(max_ds, 1, 6)
),
t1 AS (
  SELECT
    company_group,
    CONCAT('T-1单量(', max_ds, ')') AS metric,
    SUM(order_cnt) AS val
  FROM all_daily
  WHERE ds = max_ds
  GROUP BY company_group, max_ds
)
SELECT company_group, metric, val
FROM (
  SELECT * FROM fy26
  UNION ALL
  SELECT * FROM monthly
  UNION ALL
  SELECT * FROM current_month
  UNION ALL
  SELECT * FROM t1
) t
ORDER BY
  CASE
    WHEN metric = 'FY26日均(单)' THEN 1
    WHEN metric LIKE '2026%日均(单)' THEN 2
    WHEN metric LIKE '2026%截至T-1%' THEN 3
    WHEN metric LIKE 'T-1%' THEN 4
    ELSE 5
  END,
  CASE company_group
    WHEN '中通' THEN 1
    WHEN '圆通' THEN 2
    WHEN '申通' THEN 3
    WHEN '韵达' THEN 4
    WHEN '极兔速递' THEN 5
    WHEN '汇总（中通/圆通/申通/韵达/极兔）' THEN 6
    WHEN '顺丰' THEN 7
    WHEN '菜鸟速递（丹鸟）' THEN 8
    ELSE 9
  END;
