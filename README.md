# dbt Fundamentals — jaffle_shop analytics

A dbt project modeling the classic `jaffle_shop` (orders/customers), the newer
`jaffle_shop_raw` dataset (orders/items/products/stores/supplies), and
`stripe` (payments) source data into query-ready finance, marketing and
operations marts, on BigQuery.

## Architecture

```mermaid
flowchart LR
    subgraph sources [Sources]
        src_customers[(jaffle_shop.customers)]
        src_orders[(jaffle_shop.orders)]
        src_payment[(stripe.payment)]
        src_raw_orders[(jaffle_shop_raw.orders)]
        src_raw_items[(jaffle_shop_raw.order_items)]
        src_raw_products[(jaffle_shop_raw.products)]
        src_raw_stores[(jaffle_shop_raw.stores)]
        src_raw_supplies[(jaffle_shop_raw.supplies)]
    end

    subgraph staging [staging]
        stg_customers[stg_jaffle_shop__customers]
        stg_orders[stg_jaffle_shop__orders]
        stg_payment[stg_stripe__payment]
        stg_order_items[stg_jaffle_shop__order_items]
        stg_products[stg_jaffle_shop__products]
        stg_locations[stg_jaffle_shop__locations]
        stg_supplies[stg_jaffle_shop__supplies]
    end

    subgraph marts [marts]
        fct_orders[fct_orders]
        dim_customers[dim_customers]
        dim_products[dim_products]
        dim_locations[dim_locations]
        fct_order_items[fct_order_items]
    end

    src_customers --> stg_customers
    src_orders --> stg_orders
    src_payment --> stg_payment
    src_raw_items --> stg_order_items
    src_raw_orders --> stg_order_items
    src_raw_products --> stg_products
    src_raw_stores --> stg_locations
    src_raw_supplies --> stg_supplies

    stg_orders --> fct_orders
    stg_payment --> fct_orders

    stg_customers --> dim_customers
    fct_orders --> dim_customers

    stg_products --> dim_products
    stg_supplies --> dim_products
    stg_locations --> dim_locations

    stg_order_items --> fct_order_items
    dim_products --> fct_order_items
```

| Layer | Materialization | Purpose |
|---|---|---|
| `models/staging/` | view | 1:1 with sources — rename/cast columns only, no business logic |
| `models/marts/finance/fct_orders` | table | one row per order, with successful payment total |
| `models/marts/marketing/dim_customers` | table | one row per customer, with lifetime order aggregates |
| `models/marts/operations/dim_products` | table | one row per product, with supply cost and gross margin |
| `models/marts/operations/dim_locations` | table | one row per store location |
| `models/marts/operations/fct_order_items` | table | one row per item sold, with price, location and gross margin |
| `snapshots/orders_snapshot` | snapshot | type-2 history of order `status` over time |
| `seeds/order_status_descriptions` | seed | lookup table mapping raw status codes to readable labels |

**Two unrelated order spaces:** `jaffle_shop.orders` (integer ids, has
`status`) and `jaffle_shop_raw.orders` (UUID ids, has `store_id`, no
`status`) are independent synthetic datasets with no shared key — an order
in one doesn't correspond to any order in the other. `stg_jaffle_shop__orders`
feeds the status/payments/snapshot side (`fct_orders`, `dim_customers`,
`orders_snapshot`); `jaffle_shop_raw.orders` exists only so
`stg_jaffle_shop__order_items` can carry `store_id` (as `location_id`) onto
`fct_order_items`, connecting it to `dim_locations`. `jaffle_shop_raw.*` was
loaded once with `bq load` from the `dbt-labs/jaffle-shop-data` repo's
`jaffle-data/raw_*.csv` into our own project (location US) — `order_items`,
`orders` and `stores` must all come from the same load/checkout, since their
UUIDs are randomly regenerated on every run of that dataset.

**BigQuery Sandbox note:** this GCP project has no billing account attached,
so BigQuery runs in Sandbox mode, which blocks DML (`MERGE`/`UPDATE`/
`INSERT`). That ruled out an incremental `fct_orders` (its merge-on-`order_id`
logic is DML) — it's a plain `table` rebuilt in full every run instead.
Snapshots inherently rely on `MERGE` to record changes, so `orders_snapshot`
needs `dbt run-operation reset_snapshot` run first (see below) — that drops
the table so the next `dbt snapshot` does a fresh `CREATE TABLE` instead of a
blocked `MERGE`. The tradeoff: no real history accumulates across runs while
billing stays off, since each run replaces the table rather than appending
to it. Enable billing on the project to remove all of this and get real
incremental/snapshot behavior — BigQuery's free tier (1TB queries/month)
still applies.

Stripe amounts arrive in cents; `stg_stripe__payment` converts them to dollars
via the `cents_to_dollars` macro (`macros/cents_to_dollars.sql`), so every
downstream model works in dollars.

## Setup

1. Install dependencies (a virtualenv is recommended so this doesn't collide
   with other dbt projects on your machine):
   ```
   pip install -r requirements.txt
   ```
2. Authenticate to BigQuery for local/interactive use:
   ```
   gcloud auth application-default login
   ```
   (opens a browser — sign in with the Google account tied to your GCP
   project)
3. Copy `profiles.yml.example` to `~/.dbt/profiles.yml` (or point
   `DBT_PROFILES_DIR` at a folder containing it), set `project` to **your
   own** GCP project ID (not `dbt-tutorial` — that's dbt Labs' project; you
   need somewhere of your own for dbt to create output datasets and for
   BigQuery to bill the jobs against), and set `dataset` to a schema name
   you want dbt to create there.
4. Install packages and build:
   ```
   dbt deps
   dbt run-operation reset_snapshot
   dbt build
   ```
   The `reset_snapshot` step is only needed because this project runs in
   BigQuery Sandbox mode — see the note above. Skip it once billing is
   enabled on the project.

## Everyday commands

| Command | What it does |
|---|---|
| `dbt run-operation reset_snapshot && dbt build` | the full build, safe to re-run any time (Sandbox mode) |
| `dbt run` | build models only |
| `dbt test` | run schema + singular tests only |
| `dbt seed` | load `seeds/order_status_descriptions.csv` |
| `dbt run-operation reset_snapshot && dbt snapshot` | rebuild `orders_snapshot` (Sandbox mode) |
| `dbt docs generate && dbt docs serve` | build and browse the docs site / DAG |
| `sqlfluff lint models` | lint SQL style (matches CI) |

## Testing strategy

- **Sources**: primary keys are `unique` + `not_null` on every raw table.
- **Staging**: primary keys re-checked after renaming; `stg_stripe__payment`
  additionally checks `payment_status` against known values and enforces
  referential integrity to `stg_jaffle_shop__orders`; `stg_jaffle_shop__order_items.location_id`
  is checked with a `relationships` test against `stg_jaffle_shop__locations`.
- **Marts**: primary keys, not-null business columns, a `relationships`
  test tying `fct_orders.customer_id` back to `stg_jaffle_shop__customers`,
  and `relationships` tests tying `fct_order_items.location_id` /
  `.product_id` back to `dim_locations` / `dim_products`.
- **Singular test**: `tests/assert_stg_stripe___payments_total_positive.sql`
  guards against negative payment totals per order.
- Every model and source column has a `description`, so `dbt docs generate`
  produces a fully documented site — no orphan tables.

## CI

`.github/workflows/dbt_ci.yml` has two jobs:

- **`checks`** — runs on every push/PR, no secrets needed. `dbt parse`
  doesn't open a warehouse connection, so it still catches broken
  `ref`/`source` calls, invalid YAML, and Jinja errors for free.
- **`lint_and_build`** — `sqlfluff lint` (its dbt templater needs a live
  connection to build a relations cache), `dbt run-operation reset_snapshot`
  (see the Sandbox mode note above), then `dbt build` against BigQuery.
  Gated behind the `BIGQUERY_CI_ENABLED` repository variable (already set to
  `true`) and the `BIGQUERY_KEYFILE_JSON` repository secret — a key for the
  `dbt-service` service account in the `wide-isotope-409918` project, scoped
  to just `roles/bigquery.dataEditor` + `roles/bigquery.jobUser` (not
  `roles/owner`, which it started with).

## Analyses

`analyses/` holds ad-hoc SQL compiled by `dbt compile` but never built by
`dbt run`/`dbt build` — e.g. `customer_lifetime_value_ranking.sql` and
`orders_by_status.sql`.
