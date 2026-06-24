-- Inventory item expiry dates.
ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS expiry_date date;

CREATE INDEX IF NOT EXISTS idx_inventory_items_expiry_date
  ON public.inventory_items (expiry_date);

-- Keep the expiry context on each movement/history row.
ALTER TABLE public.stock_movements
  ADD COLUMN IF NOT EXISTS expiry_date date;

CREATE INDEX IF NOT EXISTS idx_stock_movements_item_created_at
  ON public.stock_movements (item_id, created_at DESC);

-- Allow manager-created staff profiles that do not have Supabase Auth users.
-- This drops only a foreign key from public.profiles.id to auth.users.id when it exists.
DO $$
DECLARE
  fk_name text;
BEGIN
  SELECT tc.constraint_name
  INTO fk_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
   AND tc.table_schema = kcu.table_schema
  JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_name = ccu.constraint_name
   AND tc.table_schema = ccu.constraint_schema
  WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    AND tc.table_name = 'profiles'
    AND kcu.column_name = 'id'
    AND ccu.table_schema = 'auth'
    AND ccu.table_name = 'users'
    AND ccu.column_name = 'id'
  LIMIT 1;

  IF fk_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.profiles DROP CONSTRAINT %I', fk_name);
  END IF;
END $$;
