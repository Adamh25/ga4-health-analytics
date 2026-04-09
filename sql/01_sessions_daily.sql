-- ============================================================
-- 01_sessions_daily.sql
-- Daily session volume, engagement time, and engaged session rate
--
-- Source: GA4 BigQuery native export (events_* partitioned tables)
-- Output fields: date, sessions, engaged_sessions, engagement_rate,
--                avg_engagement_seconds, pdf_downloads, cme_completions
-- ============================================================

WITH raw_events AS (

  SELECT
    PARSE_DATE('%Y%m%d', event_date)                          AS date,
    user_pseudo_id,
    event_name,

    -- Extract session ID from nested event_params
    (SELECT value.int_value
     FROM UNNEST(event_params)
     WHERE key = 'ga_session_id')                            AS session_id,

    -- Extract engagement time (milliseconds) for this event
    (SELECT value.int_value
     FROM UNNEST(event_params)
     WHERE key = 'engagement_time_msec')                     AS engagement_time_msec,

    -- Extract page path for content-level filtering
    (SELECT value.string_value
     FROM UNNEST(event_params)
     WHERE key = 'page_location')                            AS page_location

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

  -- Restrict to date range; swap these values for your own window
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'

),

-- Aggregate engagement time to session level using window function
-- GA4 splits engagement_time_msec across multiple events per session;
-- summing at session level gives total engaged time
session_engagement AS (

  SELECT
    date,
    session_id,
    user_pseudo_id,

    -- Sum engagement time across all events in the session
    SUM(engagement_time_msec)                                AS session_eng_ms,

    -- Flag CME-relevant events (remapped from ecommerce equivalents)
    -- In a real health platform: replace with actual GA4 custom event names
    COUNTIF(event_name = 'purchase')                         AS cme_completions,    -- maps to cme_module_complete
    COUNTIF(event_name = 'add_to_cart')                      AS cme_starts,         -- maps to cme_module_start
    COUNTIF(event_name = 'begin_checkout')                   AS pdf_downloads       -- maps to pdf_download

  FROM raw_events
  WHERE session_id IS NOT NULL
  GROUP BY 1, 2, 3

),

-- Day-level aggregation
daily AS (

  SELECT
    date,

    COUNT(DISTINCT session_id)                               AS sessions,

    -- GA4 defines an engaged session as >10 seconds engagement time
    COUNT(DISTINCT CASE WHEN session_eng_ms > 10000
      THEN session_id END)                                   AS engaged_sessions,

    -- Average engagement time in seconds (rounded to 1dp)
    ROUND(AVG(session_eng_ms) / 1000, 1)                    AS avg_engagement_seconds,

    SUM(pdf_downloads)                                       AS pdf_downloads,
    SUM(cme_completions)                                     AS cme_completions,
    SUM(cme_starts)                                          AS cme_starts

  FROM session_engagement
  GROUP BY 1

)

SELECT
  date,
  sessions,
  engaged_sessions,

  -- Engagement rate as a percentage (2dp)
  ROUND(100 * engaged_sessions / NULLIF(sessions, 0), 2)    AS engagement_rate_pct,

  avg_engagement_seconds,
  pdf_downloads,
  cme_completions,
  cme_starts,

  -- CME completion rate as a percentage
  ROUND(100 * cme_completions / NULLIF(cme_starts, 0), 2)   AS cme_completion_rate_pct

FROM daily
ORDER BY date ASC;
