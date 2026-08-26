# Complete Guide: Migrating iZiiServer Database from SQLite to PostgreSQL

**Target System:** iZiiApp Server (FastAPI Backend on Windows)  
**Updated Date:** 26/08/2026  
**Execution Script:** `server/migrate_to_postgres.py`  
**Related Docs:** [HUONG_DAN_CHUYEN_DATABASE_POSTGRES.md](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/server/HUONG_DAN_CHUYEN_DATABASE_POSTGRES.md), [plan_backup_DB.md](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/server/plan/plan_backup_DB.md)

---

## 📑 TABLE OF CONTENTS

1. [Overview & Safety Principles](#1-overview--safety-principles)
2. [Prerequisites](#2-prerequisites)
3. [Step-by-Step 8-Stage Migration Process](#3-step-by-step-8-stage-migration-process)
4. [Post-Migration Smoke Testing](#4-post-migration-smoke-testing)
5. [Rollback Procedure (Emergency Fallback to SQLite)](#5-rollback-procedure-emergency-fallback-to-sqlite)
6. [Troubleshooting & FAQs](#6-troubleshooting--faqs)

---

## 1. Overview & Safety Principles

When scaling iZiiServer from SQLite to PostgreSQL to handle high concurrent write throughput and eliminate database lock contention (`database is locked`), the migration procedure adheres to three non-negotiable principles:

* **Zero Data Loss:** All 13 relational tables—including mutation event logs, auth tokens, device identities, encrypted chat queues, and work sessions—are transferred completely.
* **Monotonic Sequence Preservation (`seq`):** The synchronization cursor sequence (`seq`) is preserved exactly without renumbering. Renumbering sequences would cause mobile clients (iPhone, iPad, Samsung/Android) to lose synchronization state or re-download millions of old records.
* **Client-Side Transparency:** Mobile devices in the field continue operating without requiring re-authentication, app reinstallation, or configuration changes.

---

## 2. Prerequisites

### 2.1 PostgreSQL Instance Setup
* Supported versions: **PostgreSQL 15 or 16** (installed on Windows or running in Docker).
* Create a dedicated database with UTF-8 encoding:
```sql
-- Connect via psql or pgAdmin
CREATE DATABASE "iZiiApp" WITH ENCODING 'UTF8';
```

### 2.2 Install PostgreSQL Python Driver
Open **PowerShell** or **Command Prompt** with administrative privileges and install `psycopg` with connection pooling support:
```powershell
pip install "psycopg[binary,pool]>=3.1"
```

---

## 3. Step-by-Step 8-Stage Migration Process

```mermaid
flowchart TD
    S1["Step 1: Backup SQLite & uploads/"] --> S2["Step 2: Set IZIIAPP_PG_DSN in .env"]
    S2 --> S3["Step 3: Stop iZiiServer Service"]
    S3 --> S4["Step 4: Execute Dry-Run (--dry-run)"]
    S4 --> S5["Step 5: Execute Live Migration"]
    S5 --> S6["Step 6: Verify Row Counts (--verify)"]
    S6 --> S7["Step 7: Set IZIIAPP_DB_BACKEND=postgres"]
    S7 --> S8["Step 8: Start Server & Smoke Test"]
```

---

### Step 1: Pre-Migration Safety Backup
Before executing any migration commands, create a complete cold backup of the active SQLite database file and the static `uploads/` directory:
```powershell
# Create temporary backup directory
New-Item -ItemType Directory -Path "D:\Backup_Pre_Migration" -Force

# Copy SQLite database file (default path: %LOCALAPPDATA%\iZiiApp\server\iziiapp.db)
Copy-Item "$env:LOCALAPPDATA\iZiiApp\server\iziiapp.db" "D:\Backup_Pre_Migration\iziiapp.db" -Force

# Copy uploaded attachments directory
Copy-Item "$env:LOCALAPPDATA\iZiiApp\server\uploads" "D:\Backup_Pre_Migration\uploads" -Recurse -Force
```

---

### Step 2: Configure PostgreSQL DSN in `.env`
Open `server/.env` and configure the connection parameters under `IZIIAPP_PG_DSN`.  
*(Note: Do NOT change `IZIIAPP_DB_BACKEND` yet at this stage)*:

```env
# Format: postgresql://<username>:<password>@<host>:<port>/<database_name>
IZIIAPP_PG_DSN=postgresql://postgres:Admin@127.0.0.1:5432/iZiiApp
IZIIAPP_PG_POOL_MIN=1
IZIIAPP_PG_POOL_MAX=10
```

---

### Step 3: Stop iZiiServer Service
Halt the server process to ensure no new mutations or uploads occur during database extraction:
```powershell
# If running as a Windows Service (via NSSM):
nssm stop izii_server

# Or if running interactively in terminal / batch script:
# Press Ctrl+C in the active terminal window
```

---

### Step 4: Execute Pre-Flight Dry-Run (`--dry-run`)
Run the migration script in simulation mode to validate data constraints (`seq IS NULL`, NOT NULL rules, column types) and review table row statistics:
```powershell
cd C:\Users\CHANH\OneDrive\Documents\Downloads\Compressed\izii_app\server
python migrate_to_postgres.py --dry-run
```
**Expected Output:**
```text
✅ Pre-flight checks đạt yêu cầu.
🧪 [DRY-RUN] Kiểm tra schema và số lượng dòng hiện có ở SQLite:
   • sync_mutations        : 161    dòng (11 cột)
   • known_servers         : 2      dòng (8 cột)
   • devices               : 4      dòng (10 cột)
   ...
✅ [DRY-RUN] Hoàn tất kiểm tra: tổng cộng ~180 dòng sẵn sàng migrate.
```

---

### Step 5: Execute Live Data Migration
Execute the migration script to populate PostgreSQL:
```powershell
python migrate_to_postgres.py
```
**Automated operations executed by the script:**
1. Automatically applies DDL statements and creates all 13 PostgreSQL tables with proper indexing.
2. Validates table coverage (`_assert_table_coverage`).
3. Streams data in 500-row chunks using `fetchmany()` to prevent RAM exhaustion.
4. Executes `setval(pg_get_serial_sequence('sync_mutations', 'seq'), MAX(seq))` to ensure future insert operations receive monotonic sequence numbers exceeding the historical maximum.
5. Displays `✅ Hoàn tất migrate thành công: ... dòng.`

---

### Step 6: Verify Database Parity (`--verify`)
Perform an independent row count audit comparing both databases:
```powershell
python migrate_to_postgres.py --verify
```
**Expected Output:**
All 13 tables must display `[OK]` status with matching `SQLite == PostgreSQL` counts.

---

### Step 7: Activate PostgreSQL Backend
Edit `server/.env` to switch the primary backend driver:
```env
IZIIAPP_DB_BACKEND=postgres
```

---

### Step 8: Start Server & Monitor
Start the iZiiServer service:
```powershell
# If using NSSM Service:
nssm start izii_server

# Or running directly via Python:
python app.py
```

---

## 4. Post-Migration Smoke Testing

Perform these validation tests immediately after server startup. Tests 4 and 5 are
**mandatory** — without them you cannot claim the migration succeeded.

### 1. Verify Startup Logs
Check the server stdout or log file (`%LOCALAPPDATA%\iZiiApp\server\logs\server.log`) for the following entries:
```text
🗄️  Database backend: postgres
🐘 [PG] Connection pool sẵn sàng (min=1, max=10)
🐘 [PG] Schema PostgreSQL đã sẵn sàng.
```

### 2. Verify API Health Endpoint
Query the server status endpoint:
```powershell
curl http://127.0.0.1:8080/sync/status
```
The response should return a valid JSON payload containing total records and per-table breakdowns (`grow_rooms`, `mushroom_jobs`, `tasks`, etc.).

### 3. Verify Mobile Client Synchronization (iPhone / iPad / Samsung)
1. Launch iZiiApp on a physical mobile device connected to the local network.
2. Create or update an operational record (e.g., save a room inspection checklist or check-in log).
3. Confirm the mobile UI reports `Synced` status.
4. Verify in PostgreSQL that the new mutation was recorded with an incremented sequence:
   ```sql
   SELECT id, seq, "table", operation, server_received_at 
   FROM sync_mutations 
   ORDER BY seq DESC 
   LIMIT 5;
   ```

### 4. Regression Test for Defect M1 — the Four Previously Omitted Tables ⚠️ MANDATORY

`device_tokens`, `employee_pins`, `work_sessions` and `enrollment_tokens` were absent from the
migration table list and were lost silently. This test proves the defect is gone:

```sql
SELECT 'device_tokens'     AS table_name, COUNT(*) FROM device_tokens
UNION ALL SELECT 'employee_pins',     COUNT(*) FROM employee_pins
UNION ALL SELECT 'work_sessions',     COUNT(*) FROM work_sessions
UNION ALL SELECT 'enrollment_tokens', COUNT(*) FROM enrollment_tokens;
```

Counts must match SQLite. Note: if these tables are empty in SQLite, this test **proves
nothing** — the unpatched script would produce identical output. Run it against a copy of the
production database that holds real rows in all four tables.

The behavioural check matters more than the counts: **sign in with an employee PIN**, and
**open the app on a device enrolled before the migration** without re-enrolling. If
`device_tokens` was lost, the device is kicked back to the enrolment screen — the most
recognisable symptom.

### 5. Mixed-Backend Peer Sync: PostgreSQL Node ↔ SQLite Node ⚠️ MANDATORY

All three plants cannot be cut over in a single night, so there **will** be a period where M1
runs PostgreSQL while M2 and Cool Room still run SQLite. If the mesh cannot operate in a mixed
configuration, the entire node-by-node rollout collapses into a far riskier big-bang cutover.

1. Stand up two servers: node A with `IZIIAPP_DB_BACKEND=postgres`, node B on `sqlite`.
   Declare each other via `IZIIAPP_PEERS`.
2. Create a record on node A → wait up to 45 s (`IZIIAPP_SYNC_INTERVAL_SECONDS`) → confirm it
   appears on node B.
3. Repeat in reverse: create on node B → confirm on node A.
4. Inspect the sync cursors on both sides:
   ```sql
   SELECT server_id, last_synced_seq, last_seen_online_at FROM known_servers;
   ```
   `last_synced_seq` must advance on both sides — never stall, never move backwards.
5. Sever the link between A and B for ~5 minutes, write records on both, then restore the
   link. Both must catch up with no lost and no duplicated rows.

### 6. Vietnamese Collation Check

PostgreSQL sorts strings according to the database collation, which **differs from SQLite's
default `BINARY`**. Employee names carrying diacritics will sort differently. Decide this
before go-live: changing collation afterwards requires rebuilding every affected index.

```sql
SELECT user_name FROM work_sessions
WHERE user_name IS NOT NULL
ORDER BY user_name;
```

Compare the ordering against the same query on SQLite. If it differs and the difference is
**not acceptable**, settle the collation (`en_US.UTF-8`, or ICU `vi-VN`) **before** cutover,
not after. Also exercise case-insensitive lookups: SQLite's `COLLATE NOCASE` **does not exist**
in PostgreSQL — use `ILIKE` where that behaviour is required.

---

## 5. Rollback Procedure (Emergency Fallback to SQLite)

If an unexpected issue arises during initial production operation and you need to revert to SQLite:

### Step 1: Stop Server Service
```powershell
nssm stop izii_server
```

### Step 2: Revert Environment Backend
In `server/.env`, set:
```env
IZIIAPP_DB_BACKEND=sqlite
```

### Step 3: Re-align SQLite Sequence Counter
If new mutations were recorded while running on PostgreSQL, update SQLite's `sync_sequence` counter to match the highest sequence generated to prevent key collisions:
```powershell
python -c "import sqlite3; from database import DB_PATH; conn=sqlite3.connect(DB_PATH); max_seq=conn.execute('SELECT COALESCE(MAX(seq), 0) FROM sync_mutations').fetchone()[0]; conn.execute('UPDATE sync_sequence SET current = ? WHERE name = \'mutation\'', (max_seq,)); conn.commit(); conn.close(); print('Successfully restored sync_sequence =', max_seq)"
```

### Step 4: Restart Service
```powershell
nssm start izii_server
```

---

## 6. Troubleshooting & FAQs

### 🔴 Issue 1: `Connection refused (port 5432)`
* **Cause:** The PostgreSQL service is stopped on the Windows host.
* **Resolution:** Open `services.msc`, locate `postgresql-x64-15` (or `16`), right-click, and select **Start**.

### 🔴 Issue 2: `password authentication failed for user "postgres"`
* **Cause:** Incorrect password specified in `IZIIAPP_PG_DSN`.
* **Resolution:** Verify the database credentials and update `server/.env`.

### 🔴 Issue 3: `database "iZiiApp" does not exist`
* **Cause:** Target database has not been created or case-sensitivity mismatch.
* **Resolution:** Connect via `psql` or `pgAdmin` and execute: `CREATE DATABASE "iZiiApp";`.

### 🔴 Issue 4: Missing Image Attachments
* **Cause:** The `uploads/` directory was not copied when changing host machines.
* **Resolution:** Image files reside on the physical filesystem at `%LOCALAPPDATA%\iZiiApp\server\uploads\`. Ensure this directory is synced to the target host matching the configured path in `server_config.py`.

### 🔴 Issue 5: `migrate_to_postgres.py` Aborts Mid-Run

* **Cause:** The script commits **per table**, with no enclosing transaction. A failure on
  table N leaves the preceding N-1 tables already committed in PostgreSQL.
* **Resolution:** Re-running is safe with respect to duplicates (`ON CONFLICT DO NOTHING`),
  but it **cannot remove rows already inserted** if the failure was caused by bad data. The
  clean, definitive recovery is:

  ```sql
  DROP DATABASE iziiapp;
  CREATE DATABASE iziiapp;
  ```
  ```powershell
  python migrate_to_postgres.py
  ```

  This is only available while `IZIIAPP_DB_BACKEND=postgres` has **not** yet been set — that
  is, while no new data exists solely in PostgreSQL. After cutover, restore from the Step 1
  backup instead.

### 🔴 Issue 6: `⛔ DỪNG: iZiiServer đang chạy trên cổng 8080`

* **Cause:** The script refuses to run while the server is live, because mutations written
  during the copy can be silently missed.
* **Resolution:** Stop the service first (`nssm stop izii_server`, or `Ctrl+C` in the
  terminal). Use `--force` only when you are certain nothing is writing.

### 🔴 Issue 7: `⛔ DỪNG: N bảng có trong SQLite nhưng KHÔNG nằm trong TABLES`

* **Cause:** A table was added to `db_init.py` without being declared in
  `migrate_to_postgres.py`. This is the guard that prevents a repeat of the four-table data
  loss.
* **Resolution:** If the table **should** migrate, add it to `TABLES` (with its primary key)
  **and** add the matching DDL to `db_init_postgres.py`. If it is **intentionally** excluded,
  add its name to `NOT_MIGRATED` with a documented reason. Never delete the guard to make the
  script run.
