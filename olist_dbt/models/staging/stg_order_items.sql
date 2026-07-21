select
    order_id,
    price,
    freight_value
from {{ source('olist_raw', 'order_items') }}
