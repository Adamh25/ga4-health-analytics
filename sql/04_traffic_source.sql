-- Output fields: source, medium, channel_group, sessions,
--                engaged_sessions, engagement_rate_pct,
--                avg_engagement_seconds, cme_completions,
--                cme_completion_rate_pct

WITH session_source AS (

  -- Pull traffic attribution from the session_start event only
  -- GA4 attributes source/medium at session level
  SELECT
    (SELECT value.int_value
     FROM UNNEST(event_params)
     WHERE key = 'ga_session_id')                              AS session_id,

    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date)                           AS date,

    -- Session-level traffic dimensions
    traffic_source.source                                      AS source,
    traffic_source.medium                                      AS medium,
    traffic_source.name                                        AS campaign

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'session_start'

),

-- Pulls engagement and conversion metrics for all events
session_metrics AS (

  SELECT
    (SELECT value.int_value
     FROM UNNEST(event_params)
     WHERE key = 'ga_session_id')                              AS session_id,

    SUM((SELECT value.int_value
         FROM UNNEST(event_params)
         WHERE key = 'engagement_time_msec'))                  AS session_eng_ms,

    COUNTIF(event_name = 'purchase')                           AS cme_completions,
    COUNTIF(event_name = 'add_to_cart')                        AS cme_starts

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'

  GROUP BY 1

),

-- Join source to metrics
joined AS (

  SELECT
    ss.session_id,
    ss.source,
    ss.medium,
    ss.campaign,

    -- Apply GA4-style default channel grouping
    CASE
      WHEN ss.medium = 'organic'                             THEN 'Organic Search'
      WHEN ss.medium IN ('cpc', 'paid', 'ppc')              THEN 'Paid Search'
      WHEN ss.medium = 'email'                               THEN 'Email'
      WHEN ss.medium = 'referral'                            THEN 'Referral'
      WHEN ss.medium IN ('social', 'social-network')         THEN 'Organic Social'
      WHEN ss.source = '(direct)' AND ss.medium = '(none)'  THEN 'Direct'
      ELSE 'Other'
    END                                                        AS channel_group,

    sm.session_eng_ms,
    sm.cme_completions,
    sm.cme_starts

  FROM session_source ss
  LEFT JOIN session_metrics sm USING (session_id)

)

SELECT
  source,
  medium,
  channel_group,

  COUNT(DISTINCT session_id)                                   AS sessions,

  COUNT(DISTINCT CASE WHEN session_eng_ms > 10000
    THEN session_id END)                                       AS engaged_sessions,

  ROUND(
    100 * COUNT(DISTINCT CASE WHEN session_eng_ms > 10000 THEN session_id END)
        / NULLIF(COUNT(DISTINCT session_id), 0), 2
  )                                                            AS engagement_rate_pct,

  ROUND(AVG(session_eng_ms) / 1000, 1)                        AS avg_engagement_seconds,

  SUM(cme_completions)                                         AS cme_completions,
  SUM(cme_starts)                                              AS cme_starts,

  ROUND(
    100 * SUM(cme_completions) / NULLIF(SUM(cme_starts), 0), 2
  )                                                            AS cme_completion_rate_pct

FROM joined
GROUP BY 1, 2, 3

-- Focuses on meaningful traffic sources, adjustable
HAVING COUNT(DISTINCT session_id) >= 20

ORDER BY sessions DESC;
