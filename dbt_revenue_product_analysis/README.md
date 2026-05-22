# dbt Revenue & Product Analysis

A dbt project that models raw SaaS event, subscription, and payment data into analytics-ready tables in Databricks. The marts layer powers two executive dashboards and a self-serve exploration tool.

## Business questions answered

| Area | Questions |
|---|---|
| **Revenue** | How has MRR evolved? What drives growth vs churn? What is the revenue waterfall by movement type? |
| **Retention** | What is the cohort retention rate over 12 months? Does activation improve retention? |
| **Product funnel** | Where do users drop off in the funnel? What is the time to activation and conversion? |
| **Payments** | What is the payment success rate by plan and billing cycle? |
| **Subscriptions** | What is the churn rate? What are the most common cancellation reasons? |

## Data model

```
                      ┌─────────────┐
                      │  0_sources  │  Raw tables in Databricks (0_raw schema)
                      │  (revenue)  │  events · payments · subscriptions · users · plans
                      └──────┬──────┘
                             │ rename, cast, clean
                      ┌──────▼──────┐
                      │  1_staging  │  Views — one per source table
                      │  (views)    │  stg_revenue__*
                      └──────┬──────┘
                             │ complex business logic
                      ┌──────▼──────────┐
                      │ 2_intermediate  │  Views — reusable building blocks
                      │ (views)         │  int_revenue__cohort_retention
                      └──────┬──────────┘
                             │ denormalise, aggregate
               ┌─────────────▼─────────────┐
               │         3_marts           │  Tables — analytics-ready
               │                           │
               │  Dimensions               │  Facts
               │  ─────────────            │  ──────────────────────────
               │  dim_users                │  fct_mrr
               │  dim_plans                │  fct_payments
               │                           │  fct_subscriptions
               │                           │  fct_events
               │                           │  fct_cohort_retention
               │                           │  fct_user_funnel
               └───────────────────────────┘
```

## Models

### Staging (`1_staging`) — views, schema: `1_staging`

| Model | Grain | Description |
|---|---|---|
| `stg_revenue__events` | event_id | User and system events with funnel stage classification |
| `stg_revenue__payments` | payment_id | Payment transactions with status normalisation |
| `stg_revenue__subscriptions` | subscription_id | Subscription lifecycle with MRR and churn flags |
| `stg_revenue__users` | user_id | User profiles with acquisition channel and company attributes |
| `stg_revenue__plans` | plan_id | Plan catalogue with pricing from seed data |

### Intermediate (`2_intermediate`) — views, schema: `2_intermediate`

| Model | Grain | Description |
|---|---|---|
| `int_revenue__cohort_retention` | cohort_month × months_since_cohort | Retention rates with activated vs non-activated split |

### Dimensions (`3_marts`) — tables, schema: `3_marts`

| Model | Grain | Description |
|---|---|---|
| `dim_users` | user_id | User attributes for slicing and filtering. Join via `sk_user_id` |
| `dim_plans` | plan_id | Plan pricing and feature attributes. Join via `sk_plan_id` |

### Facts (`3_marts`) — tables, schema: `3_marts`

| Model | Grain | Description |
|---|---|---|
| `fct_mrr` | subscription_id × mrr_month | MRR periodic snapshot with movement type classification (new / expansion / contraction / reactivation / retained / churned). Includes synthetic churn rows |
| `fct_payments` | payment_id | Payment transactions enriched with plan and user keys |
| `fct_subscriptions` | subscription_id | Subscription lifecycle with duration, MRR, and churn metrics |
| `fct_events` | event_id | Enriched events with funnel stage order and activation/conversion flags |
| `fct_cohort_retention` | cohort_month × months_since_cohort | Retention heatmap data with SaaS benchmark comparisons |
| `fct_user_funnel` | user_id | Accumulating snapshot of each user's highest funnel stage, time-to-milestone, and subscription status |

## Analyses

`analyses/business_questions.sql` contains 14 ad-hoc queries that directly address the business questions above. Unlike models, analyses are not materialised — they run on demand against the mart tables.

Compile to render Jinja references before executing:

```bash
dbt compile --select analyses/business_questions.sql --profiles-dir .
```

The compiled SQL lands in `target/compiled/`. Copy the relevant query into your Databricks SQL editor or BI tool.

| # | Question | Key tables |
|---|---|---|
| 1 | MRR/ARR over time | `fct_mrr` |
| 2 | Revenue change drivers — MRR waterfall | `fct_mrr` |
| 3 | Revenue churn rate and net revenue retention | `fct_mrr` |
| 4 | Revenue by customer segment (latest month) | `fct_mrr`, `dim_users`, `dim_plans` |
| 5 | ARPU by plan over time | `fct_mrr`, `dim_plans` |
| 6 | Customer lifetime value (LTV) by plan | `fct_subscriptions`, `dim_plans` |
| 7 | Revenue seasonality | `fct_mrr` |
| 8 | Funnel conversion rates — global totals | `fct_user_funnel` |
| 9 | Funnel drop-off map | `fct_user_funnel` |
| 10 | Median and average time to activation and conversion | `fct_user_funnel` |
| 11 | Activation impact on retention across cohorts | `fct_cohort_retention` |
| 12 | Converters vs non-converters by segment | `fct_user_funnel` |
| 13 | Full cohort retention heatmap with SaaS benchmark | `fct_cohort_retention` |
| 14 | Conversion and activation rate by acquisition channel | `fct_user_funnel` |
| 15 | Most common cancellation reasons by plan | `fct_subscriptions`, `dim_plans` |
| 16 | Payment success rate by plan and billing cycle | `fct_payments`, `dim_plans` |

## Tech stack

| Tool | Purpose |
|---|---|
| [dbt-databricks](https://docs.getdbt.com/docs/core/connect-data-platform/databricks-setup) | SQL transformation layer on Databricks |
| [dbt_utils](https://hub.getdbt.com/dbt-labs/dbt_utils) | `date_spine`, `generate_surrogate_key` macros |
| [SQLFluff](https://sqlfluff.com) | SQL linter and formatter (Databricks dialect) |
| [pre-commit](https://pre-commit.com) | Git hook for linting on commit |
| GitHub Actions | CI/CD pipeline (see below) |

## Getting started

**Prerequisites:** Python 3.12+, access to a Databricks workspace, [`uv`](https://github.com/astral-sh/uv)

```bash
# 1. Clone and install dependencies
git clone <repo-url>
cd revenue_product_analysis
uv sync --group dev

# 2. Set environment variables for the dev target
export DB_HOST_DEV=<your-databricks-host>
export DB_HTTP_PATH_DEV=<your-warehouse-http-path>
export DB_TOKEN_DEV=<your-personal-access-token>

# 3. Validate the connection
cd dbt_revenue_product_analysis
dbt debug --target dev --profiles-dir .

# 4. Install dbt packages
dbt deps --profiles-dir .

# 5. Build all models
dbt build --target dev --profiles-dir .
```

## Development workflow

```bash
# Run and test a single model and its downstream dependencies
dbt build -s +<model_name>+ --target dev --profiles-dir .

# Lint SQL
sqlfluff lint models/

# Auto-fix linting violations
sqlfluff fix models/
```

Pre-commit hooks run SQLFluff automatically on `git commit`. To run them manually:

```bash
pre-commit run --all-files
```

## CI/CD

The project uses slim CI to keep pipeline times short on large changesets.

```
PR opened / updated
      │
      ▼
CI workflow (GitHub Actions)
  ├─ Downloads manifest.json from last prod deploy (GitHub artifact)
  ├─ dbt build -s state:modified+ --defer   ← only changed models + downstream
  │    Each PR gets an isolated schema: ci_revenue_product_analysis.PR_<n>__<sha>
  └─ Pass → PR can be merged

Merge to main
      │
      ▼
CD workflow (GitHub Actions)
  ├─ dbt build -s state:modified+           ← only changed models + downstream
  ├─ Deploys to prod_revenue_product_analysis
  └─ Uploads new manifest.json as artifact  ← feeds next CI run
```

**Required GitHub Secrets** (Settings → Secrets → Actions):

| Secret | Used by |
|---|---|
| `DB_HOST_CI` | CI workflow |
| `DB_HTTP_PATH_CI` | CI workflow |
| `DB_TOKEN_CI` | CI workflow |
| `DB_HOST_PROD` | CD workflow |
| `DB_HTTP_PATH_PROD` | CD workflow |
| `DB_TOKEN_PROD` | CD workflow |

## Testing

All models have column-level tests defined in their `.yml` files. Tests include:
- `unique` and `not_null` on all primary and foreign keys
- `accepted_values` on categorical columns (plan tiers, movement types, company sizes)
- `dbt_utils.expression_is_true` for range and business logic assertions (e.g. `retention_rate between 0 and 1`, `mrr >= 0`)

Test failures are stored in the `test_failures` schema for inspection.
