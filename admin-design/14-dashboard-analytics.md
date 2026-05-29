---
slug: dashboard-analytics
tier: 1
applies_to: [dashboard-page, chart, kpi]
must:
  - tremor_default
  - white_card_background_border_defined
  - minimal_grid_lines
  - date_range_control_always
  - handle_loading_empty_partial_failed_states
must_not:
  - rainbow_palette_unless_many_categories
  - icon_overuse_in_kpi_card
  - dashboard_dumping_every_metric
cross_ref: [00-non-negotiable, 04-tokens, 07-states, 08-components]
verifier_probes:
  - id: chart-card-border
    layer: L2
    rule: "ChartCard wraps charts with border border-border + bg-card; no shadow-2xl"
  - id: date-range-control-present
    layer: L2
    rule: "dashboard route renders a DateRange control component"
---

# 20. Dashboard and Analytics

## 20.1 Stack

Tremor components/patterns. lower-level chart control 필요 시 Recharts.

## 20.2 Chart visual rules

- white card background
- border-defined chart card
- minimal grid lines
- muted axis labels
- 다수 category 비교 아니면 rainbow palette 금지
- primary series: primary 또는 neutral foreground
- status series: semantic tone 절제

## 20.3 KPI card

```txt
label
value
optional delta
optional sparkline/trend
optional description
```

Rules:
- icon overuse 금지.
- delta color: semantic 하지만 subtle.
- date range 의존 metric 은 기간 표기.

## 20.4 Analytics states

- loading skeleton
- empty/no data
- partial data
- failed chart query
- date range change
- permission limitation
