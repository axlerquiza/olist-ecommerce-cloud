# Olist Geo Analytics (cloud stack)

Cloud pipeline for geospatial analysis, built on the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce):

```
Kaggle CSVs --dlt--> BigQuery (olist_raw) --dbt--> BigQuery (analytics_*) --> Data Studio
```

Terraform-dlt-BigQuery-dbt-Data Studio: the cloud counterpart to [`olist-ecommerce-local`](../olist-ecommerce-local) (`docker-dlt-postgres-dbt-metabase`), scoped to the geospatial notebook rather than the general EDA notebook.

## 1. Infrastructure (Terraform)

```bash
gcloud projects create olist-ecommerce-geo --name="Olist Ecommerce Geo"
gcloud billing projects link olist-ecommerce-geo --billing-account=<billing account id>
gcloud services enable bigquery.googleapis.com iam.googleapis.com --project=olist-ecommerce-geo

cd terraform
cp terraform.tfvars.example terraform.tfvars   # set project = "olist-ecommerce-geo"
terraform init
terraform apply
```

Provisions the `olist_raw` BigQuery dataset, an `olist-pipeline` service account, and `roles/bigquery.dataEditor` + `roles/bigquery.jobUser` grants for it. No GCS bucket (dlt loads directly via the BigQuery Load Jobs API) and no `analytics_*` datasets (dbt auto-creates those on first run).

Mint a key for the service account (kept out of Terraform state):

```bash
mkdir -p ~/.google/credentials
gcloud iam service-accounts keys create \
  ~/.google/credentials/olist-geo-credentials.json \
  --iam-account="$(terraform output -raw service_account_email)"
```

## 2. Load raw data (dlt)

```bash
cp .dlt/secrets.toml.example .dlt/secrets.toml   # fill in from the key JSON above
uv sync
uv run olist_dlt.py
```

Downloads the Kaggle zip and loads 5 CSVs (`customers`, `geolocation`, `order_items`, `order_reviews`, `orders`) as tables under the `olist_raw` dataset — see `olist_dlt.py`.

## 3. Transform (dbt)

Models live in `olist_dbt/`. The dbt profile (`olist_geo_bigquery`) is defined in `~/.dbt/profiles.yml` and points at the `olist-ecommerce-geo` project:

```yaml
olist_geo_bigquery:
  outputs:
    prod:
      type: bigquery
      method: service-account
      project: olist-ecommerce-geo
      dataset: analytics
      keyfile: ~/.google/credentials/olist-geo-credentials.json
      location: US
      threads: 4
      timeout_seconds: 300
  target: prod
```

```bash
cd olist_dbt
uv run --project .. dbt run
uv run --project .. dbt test
```

This builds three BigQuery datasets:

- `analytics_staging` — thin renames/casts of the 5 raw tables, plus derived 3-digit zip prefixes matching the notebook's own grain.
- `analytics_intermediate` — `int_geolocation_zip3_centroid` (one lat/lng centroid per 3-digit zip prefix) and `int_orders_geo_enriched` (order-grain delivery/freight/review metrics).
- `analytics_marts` — `mart_geo_zip3_metrics`, the single table powering the dashboard: revenue, avg ticket, freight ratio, delivery days, review score, delay %, and items/order, all at 3-digit-zip-prefix grain.

These models port the notebook's revenue/ticket/freight/delivery/review/delay/items-per-order aggregation logic into SQL, grouped by 3-digit zip prefix.

## 4. Visualize (Data Studio)

Connect a Data Studio report to `analytics_marts.mart_geo_zip3_metrics` via the native BigQuery connector (grant the connecting Google account `roles/bigquery.dataViewer` + `roles/bigquery.jobUser` on `olist-ecommerce-geo` if needed). The report covers revenue, avg ticket, freight ratio, delivery days, review score, delay %, and items per order, each mapped by zip prefix and state, with state/city filter controls. PDF exports of each page are kept in `viz/`.
