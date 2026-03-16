-- Enable Realtime for stores so customers see new canteens without refresh

ALTER PUBLICATION supabase_realtime ADD TABLE public.stores;

