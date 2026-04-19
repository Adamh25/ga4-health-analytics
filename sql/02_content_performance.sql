-- Content category is inferred from the page path prefix.
-- ============================================================

WITH page_events AS (

  SELECT
    user_pseudo_id,
    event_name,
    PARSE_DATE('%Y%m%d', event_date)                           AS date,

    (SELECT value.int_value
     FROM UNNEST(event_params)
     WHERE key = 'ga_session_id')                             AS session_id,

    (SELECT value.int_value
     FROM UNNEST(event_params)
     WHERE key = 'engagement_time_msec')                      AS engagement_time_msec,

    REGEXP_REPLACE(
      REGEXP_REPLACE(
        (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'),
        r'\?.*$', ''   
      ),
      r'/$', ''       
    )                                                          AS page_path

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN (
      'page_view',
      'scroll',         -- maps to scroll_depth_75 
      'begin_checkout', -- maps to pdf_download
      'user_engagement'
    )

),

page_sessions AS (

  SELECT
    page_path,
    session_id,

    COUNTIF(event_name = 'page_view')                          AS page_views,
    SUM(engagement_time_msec)                                  AS session_page_eng_ms,

    -- GA4 scroll event fires at 90% scroll depth by default;
    MAX(CASE WHEN event_name = 'scroll' THEN 1 ELSE 0 END)    AS reached_scroll_depth,
    MAX(CASE WHEN event_name = 'begin_checkout' THEN 1 ELSE 0 END) AS pdf_downloaded

  FROM page_events
  WHERE page_path IS NOT NULL
    AND session_id IS NOT NULL
  GROUP BY 1, 2

),

page_summary AS (

  SELECT
    page_path,

    -- Infer content category from path prefix
    -- Replace with JOIN to content taxonomy table in production
    CASE
      WHEN page_path LIKE '%/journal/%'        THEN 'Clinical Journal'
      WHEN page_path LIKE '%/cme/%'            THEN 'CME Module'
      WHEN page_path LIKE '%/symposium/%'      THEN 'Symposium'
      WHEN page_path LIKE '%/news/%'           THEN 'News & Trials'
      WHEN page_path LIKE '%/guide/%'          THEN 'Prescribing Guide'
      WHEN page_path LIKE '%/product/%'        THEN 'Product'         -- native ecommerce paths
      ELSE 'Other'
    END                                                        AS content_category,

    SUM(page_views)                                            AS page_views,
    COUNT(DISTINCT session_id)                                 AS unique_sessions,

    COUNT(DISTINCT CASE WHEN session_page_eng_ms > 10000
      THEN session_id END)                                     AS engaged_sessions,

    ROUND(AVG(session_page_eng_ms) / 1000, 1)                 AS avg_time_on_page_sec,

    ROUND(
      100 * COUNTIF(reached_scroll_depth = 1) / COUNT(*), 2
    )                                                          AS scroll_depth_75_rate_pct,

    SUM(pdf_downloaded)                                        AS pdf_downloads

  FROM page_sessions
  GROUP BY 1, 2

)

SELECT
  page_path,
  content_category,
  page_views,
  unique_sessions,
  engaged_sessions,
  ROUND(100 * engaged_sessions / NULLIF(unique_sessions, 0), 2) AS page_engagement_rate_pct,
  avg_time_on_page_sec,
  scroll_depth_75_rate_pct,
  pdf_downloads

FROM page_summary

-- Filter out very low-traffic pages to reduce noise
WHERE unique_sessions >= 10

ORDER BY engaged_sessions DESC
LIMIT 50;
