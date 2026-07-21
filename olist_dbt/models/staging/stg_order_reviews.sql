select
    order_id,
    review_score
from {{ source('olist_raw', 'order_reviews') }}
