-- customer_zip_code_prefix_3_digits ports olist_geo.ipynb cell 41's
-- customer['customer_zip_code_prefix_3_digits'] = ...str[0:3] - the join
-- key used to attach geolocation onto orders.
select
    customer_id,
    cast(customer_zip_code_prefix as int64) as customer_zip_code_prefix,
    cast(substr(cast(customer_zip_code_prefix as string), 1, 3) as int64)
        as customer_zip_code_prefix_3_digits
from {{ source('olist_raw', 'customers') }}
