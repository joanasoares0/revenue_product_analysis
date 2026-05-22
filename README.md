# Fintex Revenue & Product Analysis

## Executive Summary

Fintex is a fictional B2B SaaS platform for SME financial management. This project builds an end-to-end analytics pipeline — from raw source data to business-ready marts — to answer two core questions: **what is driving revenue growth and churn, and where is the product funnel losing users?**

The data tells a clear story: MRR grew from ~£50k (Jan 2022) to ~£800k (Dec 2024), interrupted by a churn spike in H2 2023 caused by a pricing change, followed by a product-led recovery in 2024. The pipeline surfaces these patterns through MRR waterfall analysis, cohort retention, and funnel drop-off metrics.

---

## Business Context

Fintex launched in January 2022 and grew strongly through mid-2023. A pricing change in July 2023 triggered a churn spike — 2× the normal rate — visible through cancellation reasons in the subscription data. Sign-ups also declined in the same window. By H1 2024, the business recovered through product improvements, with 20% of Growth and Scale plan users upgrading.

Key metrics embedded in the dataset:
- MRR growth: £50k → £800k over 3 years
- Churn spike: Jul–Dec 2023, churn 2× above baseline, attributable to pricing (`cancel_reason`)
- Product funnel activation rate: ~50%, with the main drop-off between `onboarding_step2` and `activated`
- Total subscription churn over 3 years: ~35%
- Expansion: 20% of Growth/Scale subscribers upgrade in the recovery period

---

## Data Questions Answered

All questions are answered in `dbt_revenue_product_analysis/analyses/business_questions.sql`. Each query includes an inline description explaining the analytical approach and why it answers the question.

**Revenue Analysis** — powered by `fct_mrr`, `fct_subscriptions`, `dim_users`, `dim_plans`
- How has MRR/ARR evolved over time?
- What are the main drivers of revenue change (new, expansion, contraction, churn)?
- What is the revenue churn rate and how is it impacting growth?
- Which customer segments generate the most revenue?
- What is ARPU and how does it vary by plan?
- What is customer lifetime value (LTV)?
- Are there seasonality patterns in revenue?

**Product Funnel** — powered by `fct_user_funnel`, `fct_cohort_retention`
- What is the conversion rate at each funnel stage?
- Where are the biggest drop-offs?
- How long does it take users to reach activation (time to first value)?
- How does activation impact retention?
- What differentiates converters from non-converters?
- What is the retention rate over time (cohort analysis)?
- Which acquisition channels convert best?

**Subscriptions & Payments** — powered by `fct_subscriptions`, `fct_payments`, `dim_plans`
- What are the most common cancellation reasons, and do they concentrate on specific plan tiers?
- What is the payment success rate by plan and billing cycle?

---

## Methodology

The pipeline follows a layered dbt architecture (sources → staging → intermediate → marts) built on Databricks.

**Data model layers:**
- `0_sources` — raw source declarations
- `1_staging` — cleaned, typed, one-to-one with source tables
- `2_intermediate` — business logic, joins, aggregations
- `3_marts` — analytics-ready dimensions and facts (star schema)

**Marts:**

| Model | Type | Grain |
|---|---|---|
| `dim_users` | Dimension | One row per user |
| `dim_plans` | Dimension | One row per plan |
| `fct_subscriptions` | Accumulating snapshot | One row per subscription |
| `fct_mrr` | Periodic snapshot | One row per subscription × month |
| `fct_payments` | Transaction | One row per payment |
| `fct_events` | Transaction | One row per product event |
| `fct_user_funnel` | Accumulating snapshot | One row per user |
| `fct_cohort_retention` | Periodic snapshot | One row per cohort × month offset |

**Catalog & environment structure:**

| Environment | Catalog | Schema pattern |
|---|---|---|
| Dev | `revenue_product_analysis` | `dev` (or per-developer prefix) |
| CI | `revenue_product_analysis` | `ci_PR_<number>__<sha>` (isolated per PR, cleaned up on merge) |
| Prod | `prod_revenue_product_analysis` | `prod` |

CI runs inside the `revenue_product_analysis` catalog in an isolated PR-scoped schema, keeping it separate from developer workspaces without requiring a dedicated catalog.

**Stack & practices:**
- **dbt Core** — transformation, testing, documentation, contracts
- **Databricks** — compute and storage (Delta Lake)
- **SQLFluff** — SQL linting via pre-commit hook
- **GitHub Actions** — CI/CD pipeline with slim CI (`state:modified+`), PR-scoped schemas, and automated cleanup on PR close

---

## Results & Business Recommendations

**Revenue**

MRR grew from ~£50k (Jan 2022) to ~£800k (Dec 2024) — a 16× increase over three years. The MRR waterfall (query 2) identifies H2 2023 as a structurally different period: churned MRR outpaced new MRR for multiple consecutive months, directly traceable to the July 2023 pricing change via `cancel_reason` in the subscription data. Revenue churn peaked at roughly 2× the baseline rate during that window. By 2024, NRR returned above 100%, driven by 20% of Growth and Scale plan subscribers upgrading — confirming the recovery was expansion-led, not new-acquisition-led.

**Recommendation:** The pricing event reveals a process gap — the business had no early-warning system for revenue churn by segment. Instrumenting a real-time churn rate monitor by `cancel_reason` and `acquisition_channel` would allow faster intervention in future pricing changes.

---

**Product Funnel**

Global activation rate is ~50%, with the primary drop-off between `onboarding_step2` and the `activated` event (query 9). Users who complete activation have significantly higher retention rates across all cohort months (query 11) — making the onboarding step 2 completion rate the single most important leading indicator for long-term retention.

Acquisition channel and company size are the strongest predictors of conversion (query 14): comparing `conversion_rate_pct` alongside `activation_rate_pct` per segment separates two failure modes — users who activate but don't convert (value or pricing fit issue) from users who never activate (onboarding issue). These require different interventions.

**Recommendation:** Prioritise fixing the onboarding step 2 drop-off before investing in top-of-funnel acquisition. Given total subscription churn over three years of ~35%, the retention improvement from higher activation rates has a larger NPV than an equivalent investment in new user growth.

---

## Next Steps

- **Source catalog separation** — sources are currently declared inside the `revenue_product_analysis` catalog alongside transformation models. A cleaner approach would be a dedicated `raw` catalog (or one catalog per source system), with each source in its own schema (e.g. `raw.subscriptions`, `raw.events`). This separates ingestion from transformation, makes access control simpler, and reflects how source data typically lands from ETL tools in production.

- **Incremental materializations** — `fct_events`, `fct_payments`, `fct_subscriptions`, and `fct_mrr` are all built incrementally (`unique_key` + `merge`). Transaction tables filter on their date column with a 3-day lookback; `fct_subscriptions` re-processes active and recently started subscriptions on each run; `fct_mrr` runs all CTEs on full history (required for correct LAG-based movement type classification) and filters only the final output to the last 3 months for the merge. Use `--full-refresh` to rebuild from scratch. Staging models remain views — incremental only applies to physical table materializations.

- **Source freshness monitoring** — sources currently have no `loaded_at_field` or `freshness:` configuration, so dbt cannot alert if raw data is stale. Adding a load timestamp column to each raw table (e.g. `_loaded_at`) and configuring `warn_after` / `error_after` thresholds in `sources.yml` would enable `dbt source freshness` checks in CI and alert on pipeline failures before they silently corrupt downstream models.
