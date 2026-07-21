-- Collapses stg_geolocation to one row per 3-digit zip prefix. The
-- notebook (olist_geo.ipynb cell 41: brazil_geo =
-- geo.set_index('geolocation_zip_code_prefix_3_digits')) never dedups -
-- it keeps every raw sample so datashader has point density to
-- rasterize. A BI tool has no use for that density; it needs one
-- representative point per prefix instead. Using AVG (not the local
-- stack's MIN, which just picks an arbitrary corner) because at this
-- much coarser 3-digit grain - which can span an entire city district -
-- an average is a meaningfully better map-marker location than a min.
select
    geolocation_zip_code_prefix_3_digits,
    avg(geolocation_lat) as geolocation_lat,
    avg(geolocation_lng) as geolocation_lng,
    min(geolocation_city) as geolocation_city,
    min(geolocation_state) as geolocation_state
from {{ ref('stg_geolocation') }}
group by geolocation_zip_code_prefix_3_digits
