-- Store-level analytics RPCs for store_owner dashboard

-- 1. Monthly revenue and orders for a store
CREATE OR REPLACE FUNCTION public.get_store_revenue_by_month(p_store_id uuid)
RETURNS TABLE (
  year INT,
  month INT,
  total_revenue BIGINT,
  orders_count INT
) LANGUAGE sql STABLE AS $$
  SELECT
    EXTRACT(YEAR  FROM created_at)::int  AS year,
    EXTRACT(MONTH FROM created_at)::int  AS month,
    SUM(total_amount)                    AS total_revenue,
    COUNT(*)                             AS orders_count
  FROM public.orders
  WHERE store_id = p_store_id
    AND status IN ('paid','confirmed')
  GROUP BY year, month
  ORDER BY year DESC, month DESC
$$;

-- 2. Best selling menu items (by quantity & revenue)
CREATE OR REPLACE FUNCTION public.get_store_best_sellers(p_store_id uuid)
RETURNS TABLE (
  menu_item_id uuid,
  name text,
  total_quantity int,
  total_revenue bigint
) LANGUAGE sql STABLE AS $$
  SELECT
    mi.id,
    mi.name,
    SUM(oi.quantity)                        AS total_quantity,
    SUM(oi.quantity * oi.unit_price)        AS total_revenue
  FROM public.order_items oi
  JOIN public.orders o      ON o.id = oi.order_id
  JOIN public.menu_items mi ON mi.id = oi.menu_item_id
  WHERE o.store_id = p_store_id
    AND o.status IN ('paid','confirmed')
  GROUP BY mi.id, mi.name
  ORDER BY total_quantity DESC
  LIMIT 10
$$;

-- 3. Rating statistics for a store
CREATE OR REPLACE FUNCTION public.get_store_rating_stats(p_store_id uuid)
RETURNS TABLE (
  avg_rating double precision,
  rating_count int,
  star_1 int,
  star_2 int,
  star_3 int,
  star_4 int,
  star_5 int
) LANGUAGE sql STABLE AS $$
  SELECT
    COALESCE(AVG(rating)::double precision, 0)                  AS avg_rating,
    COUNT(*)::int                                               AS rating_count,
    COUNT(*) FILTER (WHERE rating = 1)::int                     AS star_1,
    COUNT(*) FILTER (WHERE rating = 2)::int                     AS star_2,
    COUNT(*) FILTER (WHERE rating = 3)::int                     AS star_3,
    COUNT(*) FILTER (WHERE rating = 4)::int                     AS star_4,
    COUNT(*) FILTER (WHERE rating = 5)::int                     AS star_5
  FROM public.menu_item_reviews
  WHERE store_id = p_store_id
$$;

