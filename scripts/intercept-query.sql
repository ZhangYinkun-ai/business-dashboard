WITH params AS (
    SELECT TO_CHAR(DATEADD(GETDATE(), -1, 'dd'), 'yyyymmdd') AS t1_date
),
filtered AS (
    SELECT 
        ds,
        CASE cp_code
            WHEN 'ZTO' THEN '中通'
            WHEN 'YTO' THEN '圆通'
            WHEN 'STO' THEN '申通'
            WHEN 'YUNDA' THEN '韵达'
            WHEN 'JT' THEN '极兔'
            WHEN 'JDLKD' THEN '京东快递'
            WHEN 'EMS' THEN '邮政'
            WHEN 'POSTB' THEN '邮政'
        END AS cp_name,
        intercept_mail_cnt_1
    FROM ascp_ads.ads_ascp_ffl_reverse_intercept_order_slr_ind_section_1d
    WHERE cp_code IN ('ZTO', 'YTO', 'STO', 'YUNDA', 'JT', 'JDLKD', 'EMS', 'POSTB')
)

SELECT time_period, cp_name, mail_cnt
FROM (
    -- 1. FY26 日均单量
    SELECT 
        'FY26日均' AS time_period,
        COALESCE(cp_name, '汇总') AS cp_name,
        ROUND(SUM(intercept_mail_cnt_1) / COUNT(DISTINCT ds), 0) AS mail_cnt,
        '0' AS sort_key_1,
        '' AS sort_key_2
    FROM filtered
    WHERE ds >= '20250401' AND ds <= '20260331'
    GROUP BY cp_name WITH ROLLUP

    UNION ALL

    -- 2. 2026年各月日均单量（每月明细 + 每月汇总）
    SELECT 
        CONCAT(
            CAST(SUBSTR(month_str, 1, 4) AS STRING), 
            '年', 
            CAST(CAST(SUBSTR(month_str, 5, 2) AS BIGINT) AS STRING), 
            '月'
        ) AS time_period,
        COALESCE(cp_name, '汇总') AS cp_name,
        ROUND(SUM(intercept_mail_cnt_1) / COUNT(DISTINCT ds), 0) AS mail_cnt,
        '1' AS sort_key_1,
        month_str AS sort_key_2
    FROM (
        SELECT 
            ds,
            cp_name,
            intercept_mail_cnt_1,
            SUBSTR(ds, 1, 6) AS month_str
        FROM filtered
        WHERE ds >= '20260101' 
          AND ds <= (SELECT t1_date FROM params)
    ) t
    GROUP BY month_str, cp_name WITH ROLLUP
    HAVING month_str IS NOT NULL

    UNION ALL

    -- 3. T-1（昨天）单量
    SELECT 
        CONCAT('T-1(', (SELECT t1_date FROM params), ')') AS time_period,
        COALESCE(cp_name, '汇总') AS cp_name,
        SUM(intercept_mail_cnt_1) AS mail_cnt,
        '2' AS sort_key_1,
        '' AS sort_key_2
    FROM filtered
    WHERE ds = (SELECT t1_date FROM params)
    GROUP BY cp_name WITH ROLLUP
) t
ORDER BY sort_key_1, sort_key_2, CASE WHEN cp_name = '汇总' THEN 0 ELSE 1 END, mail_cnt DESC;
