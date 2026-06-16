-- Option A: extend existing `task` table with assignment/proof columns
ALTER TABLE public.task
  ADD COLUMN IF NOT EXISTS assigned_to uuid,
  ADD COLUMN IF NOT EXISTS done boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS proof_url text,
  ADD COLUMN IF NOT EXISTS proof_required boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz,
  ADD COLUMN IF NOT EXISTS completed_by uuid;

-- Create storage bucket `task_proofs` in Supabase UI or via API before uploading images.
