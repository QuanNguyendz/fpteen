-- Active stores ordered by popularity (orders + ratings)
-- Now also returns avg_rating and rating_count for frontend display.

CREATE OR REPLACE FUNCTION public.get_active_stores_with_stats_v2()
RETURNS TABLE (
  id UUID,
  owner_id UUID,
  name TEXT,
  description TEXT,
  logo_url TEXT,
  address TEXT,
  is_active BOOLEAN,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  avg_rating DOUBLE PRECISION,
  rating_count BIGINT
) LANGUAGE sql STABLE AS $$
  WITH order_stats AS (
    SELECT
      store_id,
      COUNT(*) AS order_count
    FROM public.orders
    WHERE status IN ('paid', 'confirmed')
    GROUP BY store_id
  ),
  rating_stats AS (
    SELECT
      r.store_id,
      AVG(r.rating)::double precision AS avg_rating,
      COUNT(r.id)::bigint AS rating_count
    FROM public.menu_item_reviews r
    GROUP BY r.store_id
  )
  SELECT
    s.id,
    s.owner_id,
    s.name,
    s.description,
    s.logo_url,
    s.address,
    s.is_active,
    s.created_at,
    s.updated_at,
    COALESCE(rs.avg_rating, 0) AS avg_rating,
    COALESCE(rs.rating_count, 0) AS rating_count
  FROM public.stores s
  LEFT JOIN order_stats o ON o.store_id = s.id
  LEFT JOIN rating_stats rs ON rs.store_id = s.id
  WHERE s.is_active = true
  ORDER BY
    COALESCE(o.order_count, 0) DESC,
    COALESCE(rs.avg_rating, 0) DESC,
    s.name ASC;
$$;

