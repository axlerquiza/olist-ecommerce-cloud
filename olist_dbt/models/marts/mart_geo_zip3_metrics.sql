-- Zip-3-digit-prefix-grain geo metrics powering the Looker Studio
-- dashboard. Direct SQL port of olist_geo.ipynb's per-region aggregation
-- section (cells 43-93): revenue, avg ticket, freight ratio, delivery
-- days, delayed %, review score, items/order - see per-column notebook
-- cell references below.
--
-- Also stores sum/count component columns alongside each avg_* column so
-- Looker Studio can compute correctly weighted rollups
-- (SUM(sum_x)/SUM(count_y)) when a filter or state/region grouping spans
-- multiple zip prefixes of very different order volume - AVG(avg_x)
-- across zips would misweight small vs. large ones.
select
    o.customer_zip_code_prefix_3_digits as geolocation_zip_code_prefix_3_digits,
    g.geolocation_lat,
    g.geolocation_lng,
    g.geolocation_city,
    g.geolocation_state,

    count(distinct o.order_id) as order_count,

    -- revenue: cell 43 - sum(price), grain-independent
    sum(o.order_price) as total_revenue,

    -- avg_ticket: cell 47 - mean of order-grain price totals
    avg(o.order_price) as avg_ticket,

    -- freight_ratio: cell 51 - mean of order-grain freight/price ratios
    avg(o.freight_ratio) as avg_freight_ratio,
    sum(o.freight_ratio) as sum_freight_ratio,
    countif(o.freight_ratio is not null) as priced_order_count,

    -- avg_delivery_time: cells 55-56 - order-grain (see
    -- int_orders_geo_enriched.sql for the notebook-deviation note)
    avg(o.delivery_days) as avg_delivery_days,
    sum(o.delivery_days) as sum_delivery_days,
    countif(o.delivery_days is not null) as delivered_order_count,

    -- avg_score: cells 75-76 - order-grain
    avg(o.avg_review_score) as avg_review_score,
    sum(o.avg_review_score) as sum_review_score,
    countif(o.avg_review_score is not null) as reviewed_order_count,

    -- delayed: cell 83 - order-grain share of orders delivered after
    -- their estimated delivery date
    avg(cast(o.is_delayed as int64)) as pct_delayed_orders,
    countif(o.is_delayed) as delayed_order_count,
    countif(o.is_delayed is not null) as delay_known_order_count,

    -- avg_qty: cells 91-93 - mean of order-grain item counts
    avg(o.item_count) as avg_items_per_order,
    sum(o.item_count) as total_items

from {{ ref('int_orders_geo_enriched') }} o
left join {{ ref('int_geolocation_zip3_centroid') }} g
    on o.customer_zip_code_prefix_3_digits = g.geolocation_zip_code_prefix_3_digits
where o.customer_zip_code_prefix_3_digits is not null
group by
    o.customer_zip_code_prefix_3_digits,
    g.geolocation_lat,
    g.geolocation_lng,
    g.geolocation_city,
    g.geolocation_state
