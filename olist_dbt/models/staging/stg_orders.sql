-- No order_status filter - olist_geo.ipynb cell 42 merges every row of
-- orders_df regardless of status; undelivered orders simply carry null
-- delivery dates, which AVG/COUNT skip downstream the same way pandas'
-- .mean() skips NaN.
select
    order_id,
    customer_id,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
from {{ source('olist_raw', 'orders') }}
