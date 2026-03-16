-- Menu item reviews (rating + content)

CREATE TABLE public.menu_item_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_item_id UUID REFERENCES public.menu_items(id) ON DELETE CASCADE NOT NULL,
  store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE NOT NULL,
  reviewer_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  content TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (menu_item_id, reviewer_id)
);

CREATE INDEX idx_reviews_menu_item_id ON public.menu_item_reviews(menu_item_id);
CREATE INDEX idx_reviews_store_id ON public.menu_item_reviews(store_id);
CREATE INDEX idx_reviews_reviewer_id ON public.menu_item_reviews(reviewer_id);

CREATE TRIGGER menu_item_reviews_set_updated_at
  BEFORE UPDATE ON public.menu_item_reviews
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- RPC: fetch menu items with rating aggregates for a store (single query)
CREATE OR REPLACE FUNCTION public.get_store_menu_with_ratings(p_store_id UUID)
RETURNS TABLE (
  id UUID,
  store_id UUID,
  category_id UUID,
  name TEXT,
  description TEXT,
  price BIGINT,
  image_url TEXT,
  is_available BOOLEAN,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  avg_rating DOUBLE PRECISION,
  rating_count BIGINT
) LANGUAGE sql STABLE AS $$
  SELECT
    mi.id,
    mi.store_id,
    mi.category_id,
    mi.name,
    mi.description,
    mi.price,
    mi.image_url,
    mi.is_available,
    mi.created_at,
    mi.updated_at,
    COALESCE(AVG(r.rating)::double precision, 0) AS avg_rating,
    COUNT(r.id) AS rating_count
  FROM public.menu_items mi
  LEFT JOIN public.menu_item_reviews r
    ON r.menu_item_id = mi.id
  WHERE mi.store_id = p_store_id
  GROUP BY mi.id
  ORDER BY mi.name;
$$;

