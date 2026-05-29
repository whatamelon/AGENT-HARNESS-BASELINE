---
slug: philosophy
tier: 1
applies_to: [all, visual-review]
must:
  - calm_precise_neutral_dense_readable_operational
must_not:
  - marketing_website_aesthetic
  - colorful_saas_landing
  - template_marketplace_dashboard
  - mobile_first_consumer_app
  - brand_heavy_product_ui
  - dark_mode_developer_console
cross_ref: [00-non-negotiable, 04-tokens, 05-spacing-type-grid]
verifier_probes:
  - id: visual-adjective-taste-filter
    layer: L4
    rule: "screenshot diff vs reference admin (e.g. Linear/Vercel/Stripe Dashboard) — neutral/border-defined/data-dense impression"
---

# 3. Visual Philosophy

## 3.1 Design target

어드민은 high-end internal operating system 처럼 느껴져야 한다: **calm / dense / exact / fast / trustworthy**.

다음처럼 보이면 안 된다:
- marketing website
- colorful SaaS landing page
- template marketplace dashboard
- mobile-first consumer app
- brand-heavy product UI
- dark-mode developer console

## 3.2 Visual adjectives

UI taste filter:

```txt
calm
precise
neutral
dense-but-readable
operational
enterprise-grade
unbranded
white-background
border-defined
token-driven
```

거부:

```txt
playful
flashy
gradient-heavy
colorful
neumorphic
glassmorphic
marketing-like
dark
cartoonish
oversized
```
