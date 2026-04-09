# GA4 BigQuery Export Schema Reference

Quick reference for the key fields used across the SQL transformations in this project. The GA4 BigQuery export uses a nested/repeated schema — most queryable fields require `UNNEST(event_params)` to access.

---

## Table Structure

GA4 exports one table per day, named `events_YYYYMMDD`. Use wildcard syntax to query across multiple days:

```sql
FROM `project.dataset.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
```

---

## Top-Level Fields (no UNNEST required)

| Field | Type | Description |
|---|---|---|
| `event_date` | STRING | Format: `YYYYMMDD`. Use `PARSE_DATE('%Y%m%d', event_date)` to cast to DATE |
| `event_name` | STRING | Name of the GA4 event (e.g. `page_view`, `session_start`, `purchase`) |
| `event_timestamp` | INTEGER | Microseconds since epoch (UTC) |
| `user_pseudo_id` | STRING | Anonymised user identifier (cookie-based) |
| `user_id` | STRING | User-provided ID if set via `gtag('set', {user_id: ...})` |
| `traffic_source.source` | STRING | Session-level traffic source (e.g. `google`, `newsletter`) |
| `traffic_source.medium` | STRING | Session-level traffic medium (e.g. `organic`, `email`) |
| `traffic_source.name` | STRING | Campaign name |
| `platform` | STRING | `WEB`, `IOS`, or `ANDROID` |
| `geo.country` | STRING | User country (from IP geolocation) |
| `geo.region` | STRING | User region/state |
| `device.category` | STRING | `desktop`, `mobile`, or `tablet` |
| `device.browser` | STRING | Browser name |

---

## event_params (UNNEST required)

`event_params` is a REPEATED RECORD. Each element has a `key` (STRING) and a `value` (one of `string_value`, `int_value`, `float_value`, `double_value`).

**Extraction pattern:**

```sql
(SELECT value.string_value
 FROM UNNEST(event_params)
 WHERE key = 'page_location')   AS page_location
```

| Key | Value type | Description |
|---|---|---|
| `ga_session_id` | `int_value` | Unique session identifier. Join on this + `user_pseudo_id` for session-level analysis |
| `ga_session_number` | `int_value` | Session number for this user (1 = first session) |
| `page_location` | `string_value` | Full URL including query string |
| `page_referrer` | `string_value` | Referring URL |
| `page_title` | `string_value` | Page `<title>` tag content |
| `engagement_time_msec` | `int_value` | Milliseconds of active engagement on the page for this event. Sum across events to get session-level total |
| `session_engaged` | `int_value` | `1` if session is engaged (>10s or 2+ page views or conversion), else `0` |
| `entrances` | `int_value` | `1` for the first event in a session, else `0` |
| `percent_scrolled` | `int_value` | Scroll depth percentage (present on `scroll` event only; default fires at 90%) |

---

## Common Patterns

### Session-level aggregation

```sql
WITH session_data AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    SUM((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engagement_time_msec')) AS total_eng_ms
  FROM `project.dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN 'YYYYMMDD' AND 'YYYYMMDD'
  GROUP BY 1, 2
)
```

### Engaged session flag (GA4 definition)

```sql
COUNT(DISTINCT CASE WHEN total_eng_ms > 10000 THEN session_id END) AS engaged_sessions
```

### Wildcard table date filtering

```sql
-- Always filter _TABLE_SUFFIX to avoid full table scans
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
```

### Stripping query strings from page paths

```sql
REGEXP_REPLACE(page_location, r'\?.*$', '') AS page_path
```

---

## Event Name Mapping (Health Platform)

This project uses the public GA4 ecommerce sample dataset. The table below documents how ecommerce event names map to the equivalent custom events in a medical education platform context.

| GA4 sample event | Health platform equivalent | Notes |
|---|---|---|
| `page_view` | `page_view` | No change needed |
| `session_start` | `session_start` | No change needed |
| `user_engagement` | `user_engagement` | No change needed |
| `scroll` | `scroll_depth_75` | Configure custom threshold in GTM |
| `add_to_cart` | `cme_module_start` | Fire when HCP begins a CME module |
| `begin_checkout` | `pdf_download` | Fire on clinical PDF download click |
| `purchase` | `cme_module_complete` | Fire on accredited CME module completion |
| `view_item` | `content_view` | Fire on journal article / guide view |
| `view_item_list` | `content_list_view` | Fire on category/listing page view |
