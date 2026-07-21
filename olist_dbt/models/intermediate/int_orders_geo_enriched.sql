-- Order-grain enrichment joining item totals, review score, and customer
-- zip prefix - the SQL equivalent of olist_geo.ipynb cell 42's
-- orders_df ⋈ order_items ⋈ customer ⋈ order_reviews merge, but rolled
-- up to one row per order_id first.
--
-- Deliberate deviations from the notebook, both flagged rather than
-- silently applied:
-- 1. Cell 42's merge leaves the working frame at order-item grain (and
--    further duplicated for any order with >1 review) before cells
--    56/75/83 average delivery time, review score, and delay % over it -
--    so multi-item orders get counted once per item in those three
--    metrics. That's a side effect of merge order, not something the
--    notebook does deliberately (cells 47/51/91 explicitly re-aggregate
--    to order grain first for ticket/freight/qty). This model computes
--    every metric from a single clean order-grain row instead.
-- 2. Cell 42 inner-merges orders_df with order_items (dropping the ~0.8%
--    of orders with zero items - order_price/freight are genuinely
--    undefined for those, so this join stays inner, matching the
--    notebook) *and* with order_reviews (dropping another ~0.8% of
--    orders that have items but no review). That second inner join
--    silently excludes review-less orders from every metric downstream,
--    including revenue and delivery time - almost certainly an
--    unintended side effect of merging reviews in for convenience, not
--    a deliberate choice to treat "no review" as "exclude from revenue
--    reporting". The review join here stays a left join: an order's
--    revenue/ticket/delivery-day data doesn't depend on whether the
--    customer left a review, and dropping ~1.5% of order volume from a
--    revenue mart over a scoring gap would be a worse, silent bug than
--    the one this deviation is avoiding.
with order_item_totals as (
    select
        order_id,
        sum(price) as order_price,
        sum(freight_value) as order_freight,
        count(*) as item_count
    from {{ ref('stg_order_items') }}
    group by order_id
),

order_review_scores as (
    select
        order_id,
        avg(review_score) as avg_review_score
    from {{ ref('stg_order_reviews') }}
    group by order_id
)

select
    o.order_id,
    c.customer_zip_code_prefix_3_digits,
    date_diff(
        date(o.order_delivered_customer_date),
        date(o.order_delivered_carrier_date),
        day
    ) as delivery_days,
    o.order_delivered_customer_date > o.order_estimated_delivery_date as is_delayed,
    it.order_price,
    it.order_freight,
    safe_divide(it.order_freight, it.order_price) as freight_ratio,
    it.item_count,
    rv.avg_review_score
from {{ ref('stg_orders') }} o
left join {{ ref('stg_customers') }} c on o.customer_id = c.customer_id
join order_item_totals it on o.order_id = it.order_id
left join order_review_scores rv on o.order_id = rv.order_id
