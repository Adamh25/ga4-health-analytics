# Looker Studio Dashboard Configuration

This document describes how to connect the BigQuery views to Looker Studio and replicate the dashboard layout.

---

## Data Sources

Create four data sources in Looker Studio, one per BigQuery view.

| Data source name | BigQuery view | Key dimensions | Key metrics |
|---|---|---|---|
| Sessions Daily | `v_sessions_daily` | `date` | `sessions`, `engaged_sessions`, `engagement_rate_pct`, `avg_engagement_seconds` |
| Content Performance | `v_content_performance` | `page_path`, `content_category` | `unique_sessions`, `engaged_sessions`, `scroll_depth_75_rate_pct` |
| CME Funnel | `v_event_funnel` | `funnel_stage`, `stage_order` | `sessions`, `drop_off_from_prev_pct`, `cumulative_conversion_pct` |
| Traffic Source | `v_traffic_source` | `channel_group`, `source`, `medium` | `sessions`, `engagement_rate_pct`, `cme_completion_rate_pct` |

### Connecting a data source

1. In your Looker Studio report: **Add data → BigQuery**
2. Select your GCP project → your reporting dataset
3. Select the view (e.g. `v_sessions_daily`)
4. Click **Add**
5. Rename the data source using the names above for clarity

---

## Dashboard Layout (4 pages)

### Page 1: Overview

**Scorecard row** (top of page, 4 scorecards side by side)

| Scorecard | Field | Format |
|---|---|---|
| Total sessions | `sessions` SUM | Number |
| Engaged sessions | `engaged_sessions` SUM | Number |
| Avg. engagement rate | `engagement_rate_pct` AVG | Percent (2dp) |
| CME completions | `cme_completions` SUM | Number |

**Time series chart** (full width below scorecards)
- Data source: Sessions Daily
- Dimension: `date`
- Metrics: `sessions`, `engaged_sessions`
- Date range: last 90 days

**Page-level filter:** Date range control → apply to all charts on page

---

### Page 2: Content Performance

**Table** (left half)
- Data source: Content Performance
- Dimensions: `content_category`, `page_path`
- Metrics: `unique_sessions`, `engaged_sessions`, `page_engagement_rate_pct`, `avg_time_on_page_sec`, `pdf_downloads`
- Sort: `engaged_sessions` DESC
- Rows per page: 20

**Bar chart** (right half, top)
- Data source: Content Performance
- Dimension: `content_category`
- Metric: `engaged_sessions`
- Sort: `engaged_sessions` DESC

**Scatter chart** (right half, bottom)
- Data source: Content Performance
- X axis: `avg_time_on_page_sec`
- Y axis: `scroll_depth_75_rate_pct`
- Bubble size: `unique_sessions`
- Dimension (colour): `content_category`

**Filter control:** `content_category` dropdown → apply to table and bar chart

---

### Page 3: CME Funnel

**Funnel chart**
- Data source: CME Funnel
- Steps dimension: `funnel_stage`
- Step order: `stage_order` ASC
- Metric: `sessions`

Note: Looker Studio does not have a native funnel chart. Use a **bar chart** sorted by `stage_order` ASC with `sessions` as the metric, styled with decreasing bar colours to represent funnel drop-off visually.

**Scorecard: overall completion rate**
- Calculated field: `SUM(cme_completions) / SUM(cme_starts) * 100`
- Format: Percent (1dp)
- Label: CME completion rate

**Table: funnel detail**
- Dimensions: `funnel_stage`
- Metrics: `sessions`, `users`, `drop_off_from_prev_pct`, `cumulative_conversion_pct`

---

### Page 4: Traffic Sources

**Pie / donut chart**
- Data source: Traffic Source
- Dimension: `channel_group`
- Metric: `sessions`

**Table**
- Data source: Traffic Source
- Dimensions: `channel_group`, `source`, `medium`
- Metrics: `sessions`, `engagement_rate_pct`, `avg_engagement_seconds`, `cme_completions`, `cme_completion_rate_pct`
- Sort: `sessions` DESC

**Heatmap / table with conditional formatting**
- Apply green → red conditional formatting to `engagement_rate_pct` and `cme_completion_rate_pct` columns in the table above
- In Looker Studio: column → style → heatmap

---

## Recommended Style Settings

| Setting | Value |
|---|---|
| Theme | Simple Dark or Simple Light |
| Primary colour | #185FA5 (matches GA4 blue) |
| Font | Google Sans or Roboto |
| Date range default | Last 30 days |
| Report-level date filter | Apply to all pages |

---

## Adding a Report-Level Date Filter

1. **Report → Manage added data sources** — ensure all 4 sources use `date` as a date field
2. **Insert → Date range control**
3. In control properties → set as report-level (applies to all pages and charts)
4. Default date range: Last 30 days
