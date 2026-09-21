-- ==============================================================================
-- Migration 0007: Fix Boolean Column Types in PostgreSQL
-- Description: Converts columns stored as INT/INTEGER to native BOOLEAN.
-- Fixes type mismatch errors: "column X is of type integer but expression is of type boolean"
-- ==============================================================================

-- 1. Table: departments
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'departments' AND column_name = 'is_seed' AND data_type = 'integer'
    ) THEN
        ALTER TABLE departments ALTER COLUMN is_seed DROP DEFAULT;
        ALTER TABLE departments ALTER COLUMN is_seed TYPE boolean USING (is_seed::int != 0);
        ALTER TABLE departments ALTER COLUMN is_seed SET DEFAULT false;
    END IF;
END $$;

-- 2. Table: picker_teams
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'picker_teams' AND column_name = 'is_seed' AND data_type = 'integer'
    ) THEN
        ALTER TABLE picker_teams ALTER COLUMN is_seed DROP DEFAULT;
        ALTER TABLE picker_teams ALTER COLUMN is_seed TYPE boolean USING (is_seed::int != 0);
        ALTER TABLE picker_teams ALTER COLUMN is_seed SET DEFAULT false;
    END IF;
END $$;

-- 3. Table: chat_messages
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_messages' AND column_name = 'is_seed' AND data_type = 'integer'
    ) THEN
        ALTER TABLE chat_messages ALTER COLUMN is_seed DROP DEFAULT;
        ALTER TABLE chat_messages ALTER COLUMN is_seed TYPE boolean USING (is_seed::int != 0);
        ALTER TABLE chat_messages ALTER COLUMN is_seed SET DEFAULT false;
    END IF;
END $$;

-- 4. Table: mushroom_job_types
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'mushroom_job_types' AND column_name = 'is_solo_job' AND data_type = 'integer'
    ) THEN
        ALTER TABLE mushroom_job_types ALTER COLUMN is_solo_job DROP DEFAULT;
        ALTER TABLE mushroom_job_types ALTER COLUMN is_solo_job TYPE boolean USING (is_solo_job::int != 0);
        ALTER TABLE mushroom_job_types ALTER COLUMN is_solo_job SET DEFAULT false;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'mushroom_job_types' AND column_name = 'is_active' AND data_type = 'integer'
    ) THEN
        ALTER TABLE mushroom_job_types ALTER COLUMN is_active DROP DEFAULT;
        ALTER TABLE mushroom_job_types ALTER COLUMN is_active TYPE boolean USING (is_active::int != 0);
        ALTER TABLE mushroom_job_types ALTER COLUMN is_active SET DEFAULT true;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'mushroom_job_types' AND column_name = 'is_custom' AND data_type = 'integer'
    ) THEN
        ALTER TABLE mushroom_job_types ALTER COLUMN is_custom DROP DEFAULT;
        ALTER TABLE mushroom_job_types ALTER COLUMN is_custom TYPE boolean USING (is_custom::int != 0);
        ALTER TABLE mushroom_job_types ALTER COLUMN is_custom SET DEFAULT false;
    END IF;
END $$;

-- 5. Table: mushroom_jobs
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'mushroom_jobs' AND column_name = 'is_solo_job' AND data_type = 'integer'
    ) THEN
        ALTER TABLE mushroom_jobs ALTER COLUMN is_solo_job DROP DEFAULT;
        ALTER TABLE mushroom_jobs ALTER COLUMN is_solo_job TYPE boolean USING (is_solo_job::int != 0);
        ALTER TABLE mushroom_jobs ALTER COLUMN is_solo_job SET DEFAULT false;
    END IF;
END $$;

-- 6. Table: mushroom_job_safety_configs
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'mushroom_job_safety_configs' AND column_name = 'auto_start_on_job_begin' AND data_type = 'integer'
    ) THEN
        ALTER TABLE mushroom_job_safety_configs ALTER COLUMN auto_start_on_job_begin DROP DEFAULT;
        ALTER TABLE mushroom_job_safety_configs ALTER COLUMN auto_start_on_job_begin TYPE boolean USING (auto_start_on_job_begin::int != 0);
        ALTER TABLE mushroom_job_safety_configs ALTER COLUMN auto_start_on_job_begin SET DEFAULT true;
    END IF;
END $$;
