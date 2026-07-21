-- Bounding box filter for mainland Brazil, matching both the local
-- ecommerce stack's stg_geolocation and olist_geo.ipynb cell 5 directly
-- (northernmost 5°16'27.8"N, westernmost 73°58'58.19"W,
-- southernmost 33°45'04.21"S, easternmost 34°47'35.33"W).
-- geolocation_zip_code_prefix_3_digits ports cell 1's
-- geo['geolocation_zip_code_prefix'].str[0:3] - the grain every metric
-- map in the notebook actually groups by.
select
    cast(geolocation_zip_code_prefix as int64) as geolocation_zip_code_prefix,
    cast(substr(cast(geolocation_zip_code_prefix as string), 1, 3) as int64)
        as geolocation_zip_code_prefix_3_digits,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    upper(geolocation_state) as geolocation_state
from {{ source('olist_raw', 'geolocation') }}
where geolocation_lat <= 5.27438888
  and geolocation_lng >= -73.98283055
  and geolocation_lat >= -33.75116944
  and geolocation_lng <= -34.79314722
