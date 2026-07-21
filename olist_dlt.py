"""dlt pipeline that downloads the Olist Brazilian E-Commerce dataset
straight from Kaggle and loads the 5 CSVs olist_geo.ipynb's geospatial
analysis actually reads as tables into BigQuery.

Run with:
    uv run olist_dlt.py
"""

import io
import zipfile
from typing import Iterator

import dlt
import pandas as pd
import requests

KAGGLE_ZIP_URL = "https://www.kaggle.com/api/v1/datasets/download/olistbr/brazilian-ecommerce"

# csv filename (inside the kaggle zip) -> dlt table name
# Scoped to the 5 tables olist_geo.ipynb reads (customers, geolocation,
# order_items, order_reviews, orders) - products/sellers/order_payments/
# product_category_name_translation are dropped since nothing downstream
# of this pipeline queries them.
FILES_TO_TABLES = {
    "olist_customers_dataset.csv": "customers",
    "olist_geolocation_dataset.csv": "geolocation",
    "olist_order_items_dataset.csv": "order_items",
    "olist_order_reviews_dataset.csv": "order_reviews",
    "olist_orders_dataset.csv": "orders",
}

# Zip-code-prefix columns must stay strings on read - they're
# zero-padded (e.g. Sao Paulo's "01037"), and pandas' default int
# inference silently drops that leading zero, corrupting the 3-digit
# truncation dbt derives downstream. olist_geo.ipynb guards against this
# the same way (cells 1, 41: dtype={'...zip_code_prefix': str}).
DTYPE_OVERRIDES = {
    "olist_customers_dataset.csv": {"customer_zip_code_prefix": str},
    "olist_geolocation_dataset.csv": {"geolocation_zip_code_prefix": str},
}

CHUNK_SIZE = 50_000


def _download_zip() -> zipfile.ZipFile:
    response = requests.get(KAGGLE_ZIP_URL, timeout=120)
    response.raise_for_status()
    return zipfile.ZipFile(io.BytesIO(response.content))


@dlt.source
def olist_source():
    archive = _download_zip()

    def make_resource(csv_name: str, table_name: str):
        @dlt.resource(name=table_name, write_disposition="replace")
        def resource() -> Iterator[dict]:
            dtype = DTYPE_OVERRIDES.get(csv_name)
            with archive.open(csv_name) as f:
                for chunk in pd.read_csv(f, chunksize=CHUNK_SIZE, dtype=dtype):
                    yield chunk.where(chunk.notna(), None).to_dict(orient="records")

        return resource

    for csv_name, table_name in FILES_TO_TABLES.items():
        yield make_resource(csv_name, table_name)


if __name__ == "__main__":
    pipeline = dlt.pipeline(
        pipeline_name="olist_geo",
        destination="bigquery",
        dataset_name="olist_raw",
    )
    load_info = pipeline.run(olist_source())
    print(load_info)
