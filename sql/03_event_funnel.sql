-- ============================================================
-- 03_event_funnel.sql
-- CME module engagement funnel: content view → module start → module complete
--
-- Source: GA4 BigQuery native export (events_* partitioned tables)
-- Output fields: funnel_stage, users, sessions, drop_off_pct, completion_rate_pct
--
-- Funnel stages (remapped from GA4 ecommerce sample events):
--   Stage 1: content_view        (page_view on a CME path)
--   Stage 2: cme_module_start    (add_to_cart in sample data)
--   Stage 3: cme_module_complete (purchase in sample data)
-- ============================================================

WITH session_funnel AS (

  SELECT
    user_pseudo_id,

    (SELECT value.int_value
     FROM UNNEST(event_params)
     WHERE key = 'ga_session_id')                              AS session_id,

    -- Stage flags: 1 if the user hit this stage in the session, else 0
    MAX(CASE WHEN event_name = 'page_view'    THEN 1 ELSE 0 END) AS saw_content,
    MAX(CASE WHEN event_name = 'add_to_cart'  THEN 1 ELSE 0 END) AS started_module,
    MAX(CASE WHEN event_name = 'purchase'     THEN 1 ELSE 0 END) AS completed_module

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(event_params) AS ep

  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('page_view', 'add_to_cart', 'purchase')

  GROUP BY 1, 2

),

-- Count distinct users and sessions at each funnel stage
funnel_counts AS (

  SELECT
    'Stage 1: Content view'      AS funnel_stage,
    1                            AS stage_order,
    COUNT(DISTINCT user_pseudo_id) AS users,
    COUNT(DISTINCT session_id)   AS sessions
  FROM session_funnel
  WHERE saw_content = 1

  UNION ALL

  SELECT
    'Stage 2: CME module start'  AS funnel_stage,
    2                            AS stage_order,
    COUNT(DISTINCT user_pseudo_id),
    COUNT(DISTINCT session_id)
  FROM session_funnel
  WHERE started_module = 1

  UNION ALL

  SELECT
    'Stage 3: CME module complete' AS funnel_stage,
    3                              AS stage_order,
    COUNT(DISTINCT user_pseudo_id),
    COUNT(DISTINCT session_id)
  FROM session_funnel
  WHERE completed_module = 1

),

-- Compute drop-off and completion rates using window function
funnel_with_rates AS (

  SELECT
    funnel_stage,
    stage_order,
    users,
    sessions,

    -- Drop-off vs previous stage
    LAG(sessions) OVER (ORDER BY stage_order)                  AS prev_stage_sessions,

    -- Overall completion rate vs stage 1
    FIRST_VALUE(sessions) OVER (ORDER BY stage_order)          AS top_of_funnel_sessions

  FROM funnel_counts

)

SELECT
  stage_order,
  funnel_stage,
  users,
  sessions,

  -- Drop-off from the preceding stage (null for stage 1)
  ROUND(
    100 * (1 - sessions / NULLIF(prev_stage_sessions, 0)), 2
  )                                                            AS drop_off_from_prev_pct,

  -- Cumulative conversion from top of funnel
  ROUND(
    100 * sessions / NULLIF(top_of_funnel_sessions, 0), 2
  )                                                            AS cumulative_conversion_pct

FROM funnel_with_rates
ORDER BY stage_order ASC;
