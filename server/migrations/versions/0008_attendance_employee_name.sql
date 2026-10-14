-- Migration 0008: Add employee_name to timesheets and attendance events
-- Supports fast name-based matching for Manager Batch Attendance and Alone Worker assignment

ALTER TABLE mushroom_daily_timesheets ADD COLUMN IF NOT EXISTS employee_name TEXT;
ALTER TABLE mushroom_attendance_events ADD COLUMN IF NOT EXISTS employee_name TEXT;
