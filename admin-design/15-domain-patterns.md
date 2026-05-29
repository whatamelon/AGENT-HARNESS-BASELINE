---
slug: domain-patterns
tier: 1
applies_to: [domain-specific]
domains: [erp, commerce, finance, crm, marketing]
must:
  - reuse_common_admin_primitives
  - apply_domain_pattern_when_match
cross_ref: [09-tables, 12-rbac, 13-feedback-overlay, 14-dashboard-analytics, 17-status]
verifier_probes:
  - id: domain-pattern-applied
    layer: L2
    rule: "intake.domain ∈ [erp,commerce,finance,crm,marketing] => corresponding section probes activated"
---

# 21. Domain Pattern Library

## 21.1 ERP / operations

```txt
Work queue
Approvals
Entities/master data
Audit logs
Imports/exports
Exception reports
```

UX:
- dense table
- bulk action
- status badge
- approval confirmation
- audit history
- strong filter

## 21.2 Commerce

```txt
Orders
Products
Inventory
Customers
Refunds
Payments
Shipments
Promotions
```

UX:
- order status timeline
- payment/refund risk confirmation
- inventory warning
- customer detail drawer
- product variants table

## 21.3 Finance / stocks / trading operations

```txt
Watchlists
Positions
Orders/trades
Risk alerts
Market data
Reconciliation
```

UX:
- high-density data
- right-aligned number
- monospace optional (ticker/ID)
- real-time refresh indicator
- AG Grid 평가 (advanced grid 가 core 면)

## 21.4 Sales / CRM

```txt
Accounts
Contacts
Leads
Deals
Pipeline
Activities
```

UX:
- saved view
- owner filter
- pipeline stage badge
- activity timeline
- bulk assignment

## 21.5 Marketing

```txt
Campaigns
Segments
Audiences
Experiments
Reports
Attribution
```

UX:
- date range control
- metric card
- segment filter
- campaign status badge
- chart + table pairing
