# GA4 → BigQuery → Looker Studio: HCP Content Analytics Pipeline

A end-to-end analytics pipeline modelling key performance indicators for a medical education and communications platform — tracking HCP engagement with CME modules, clinical journals, and MedComms content.

> Event taxonomy and content paths have been adapted to reflect a medical education use case, modelling KPIs relevant to HCP engagement with CME content and clinical publications. Underlying data is sourced from the public `bigquery-public-data.ga4_obfuscated_sample_ecommerce` dataset, which shares the identical GA4 BigQuery export schema used in production.

---

## Architecture

```
GA4 Property
    │
    │  Native BigQuery Export (daily)
    ▼
BigQuery Raw Layer
  └── events_* (partitioned by date, nested/repeated schema)
    │
    │  SQL transformations (UNNEST, window functions, aggregation)
    ▼
BigQuery Reporting Views
  ├── v_sessions_daily
  ├── v_content_performance
  ├── v_event_funnel
  └── v_traffic_source
    │
    │  Native Looker Studio connector
    ▼
Looker Studio Dashboard
  ├── Session & engagement overview
  ├── Content performance (top pages by engaged sessions)
  ├── CME funnel (start → complete)
  └── Traffic source breakdown
```

---

## Key Metrics Tracked

| Metric | Definition |
|---|---|
| Sessions | Distinct `ga_session_id` values per day |
| Engaged sessions | Sessions with >10s engagement time (GA4 native definition) |
| Avg. engagement time | Mean `engagement_time_msec` per session, in seconds |
| CME completion rate | `cme_module_complete` / `cme_module_start` |
| Scroll depth (p75) | % of sessions where `scroll_depth_75` event fired |
| PDF downloads | Count of `pdf_download` events |

---

## SQL Transformations

| File | Description |
|---|---|
| [`sql/01_sessions_daily.sql`](sql/01_sessions_daily.sql) | Daily session volume, engagement time, engaged session rate |
| [`sql/02_content_performance.sql`](sql/02_content_performance.sql) | Top content pages ranked by engaged sessions and scroll depth |
| [`sql/03_event_funnel.sql`](sql/03_event_funnel.sql) | CME module funnel: session start → module start → module complete |
| [`sql/04_traffic_source.sql`](sql/04_traffic_source.sql) | Session volume and engagement by traffic source / medium |

---

## Setup

### 1. Enable GA4 BigQuery Export

In GA4: Admin → BigQuery Links → Link to a GCP project. Daily exports land in `your_project.analytics_XXXXXXXX.events_YYYYMMDD`.

For development and testing, use the public sample dataset:
```
bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*
```

### 2. Run the SQL views in BigQuery

```sql
-- Replace the dataset reference at the top of each file with your own:
-- FROM `your_project.analytics_XXXXXXXX.events_*`

-- Then create each view:
CREATE OR REPLACE VIEW your_project.reporting.v_sessions_daily AS (
  -- paste contents of sql/01_sessions_daily.sql
);
```

### 3. Connect Looker Studio

1. New report → Add data → BigQuery
2. Select your GCP project → reporting dataset → choose a view
3. Repeat for each view as a separate data source
4. Build charts using the field names defined in each view

---

## Tech Stack

- **Google Analytics 4** — event collection and configuration
- **BigQuery** — raw export storage, SQL transformations, reporting views
- **SQL** — `UNNEST`, wildcard table queries, window functions, CTEs
- **Looker Studio** — dashboard and data visualisation
- **GCP** — underlying infrastructure (Cloud Storage, IAM, billing)

---

## Project Structure

```
ga4-health-analytics/
├── README.md
├── sql/
│   ├── 01_sessions_daily.sql
│   ├── 02_content_performance.sql
│   ├── 03_event_funnel.sql
│   └── 04_traffic_source.sql
├── looker_studio/
│   └── dashboard_config.md
└── docs/
    └── schema_reference.md
```
