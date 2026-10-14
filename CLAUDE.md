# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

iZiiApp is a local-first, offline-capable business/community platform with two halves in one repo:

- **`lib/`** — Flutter client (Android/iOS/Windows desktop) using BLoC state management, a local Drift/SQLite database, and a pluggable "module" system for business features (CRM, supply chain, accountant, mushroom farm management, etc).
- **`server/`** — A Python/FastAPI "iZiiServer" that provides multi-device sync, E2EE-oriented device enrollment, peer-to-peer server sync (LAN mesh via mDNS), and business-domain APIs. On Windows desktop, the Flutter app can spawn and manage this server as a child process (`lib/core/server/server_manager.dart`) so the desktop build is self-contained.

The current working branch (`mushroom-farm-fork`) is a product fork focused on a mushroom farm management vertical (`lib/modules/mushrooms/`); `main` tracks the general iZiiApp product. See `MUSHROOM_FARM_BRANCH_GUIDE.md` for the branching workflow expected on this fork.

## Commands

### Flutter client (`lib/`)
```bash
flutter pub get                 # install deps
flutter analyze                 # lint/static analysis (flutter_lints, see analysis_options.yaml)
flutter test                    # run all tests under test/
flutter test test/modules/mushrooms/services/mushrooms_shared_services_test.dart   # single test file
flutter build apk --debug       # Android debug build
flutter build apk --release     # Android release build
flutter build ios --release     # iOS release build
flutter build windows           # Windows desktop build
```
Codegen (Drift tables, Freezed models, JSON serialization) must be regenerated after touching `*.dart` files with `@freezed`, `@JsonSerializable`, or Drift `@DriftDatabase`/table annotations:
```bash
dart run build_runner build --delete-conflicting-outputs
```
Generated files (`*.g.dart`, `*.freezed.dart`) are excluded from analysis (see `analysis_options.yaml`) — never hand-edit them.

### Python server (`server/`)
```bash
cd server
pip install -r requirements.txt
python app.py                                  # run in dev mode (uvicorn reload, port 8080 by default)
python -m unittest tests.test_phase1_foundation # run a single test module
python -m unittest discover tests              # run all server tests
```
Tests are plain `unittest` (no pytest config in the repo) and import server modules by adding `server/` to `sys.path` — run them from inside `server/` or via `python -m unittest` with that cwd.

Building the standalone Windows executable consumed by `server_manager.dart`:
```bash
cd server
pyinstaller --clean izii_server.spec   # produces server/dist/izii_server/izii_server.exe
```
See `SERVER_REBUILD_GUIDE.md` for the full rebuild/verify procedure.

Windows installer (Inno Setup, bundles the Flutter build + `izii_server.exe`): `build_windows_installer.bat` at the repo root delegates to `windows/installer/build_installer.bat` (see `windows/installer/README.md`). `FLUTTER_BUILD_RELEASE_GUIDE.md` covers release builds.

### Version bumps
When bumping the app version, update all of: `pubspec.yaml` (`version:`), `lib/modules/{supply_chain,services,sales_crm}/manifest.dart` (`version:`), and `windows/runner/Runner.rc` (`VERSION_AS_STRING`) — see `README.md`.

## Flutter client architecture

### Layout
- `lib/main.dart` / `lib/app.dart` — entry point; wires up `AppBloc` (settings/theme/locale) and the chat `BlocProvider`, then renders `MaterialApp.router` driven by `core/navigation/app_router.dart` (go_router). On desktop app-exit, it stops the embedded server via `ServerManager().stopServer()`.
- `lib/core/` — cross-cutting infrastructure shared by all modules (database, sync, security, device identity, AI agent, navigation, theming, localization).
- `lib/modules/` — pluggable business feature packages (see Module system below).
- `lib/features/` — top-level app screens that aren't business "modules" (home, discover, profile, server selection, sharing).

### Module system (client-side)
Business features are packaged as self-contained modules implementing `IZiiModule` (`lib/core/modules/module_interface.dart`): each declares a `ModuleManifest` (id/name/version/category), Drift table names to register, `AgentTool`s to expose to the AI agent, routes, and an optional dashboard widget. `lib/core/modules/module_registry.dart` is a singleton that registers factories for all modules (`sales_crm`, `supply_chain`, `services`, `project`, `purchase`, `accountant`, `mushrooms`) and lazily instantiates/initializes them on install. When adding a new business feature, follow this module shape rather than bolting screens directly onto `app_router.dart`.

### Local data & sync
- `lib/core/database/app_database.dart` (+ `core_tables.dart`) — the Drift/SQLite database; modules contribute their own tables (see e.g. `lib/modules/mushrooms/database/`).
- `lib/core/sync/` — offline-first sync: `outbox_queue.dart` queues local mutations, `sync_service.dart` pushes/pulls them against the server's `/sync/*` endpoints, `ble_sync_manager.dart` handles device-to-device sync over Bluetooth when no server/network is reachable, `sharing_repository.dart` / `sync_config_repository.dart` manage sharing state and server connection config.
- `lib/core/server/server_manager.dart` — starts/stops/health-checks the embedded `izii_server.exe` subprocess (Windows-only; searches several candidate paths for the built binary) and streams its logs into the app.

**Drift schema changes**: `AppDatabase` is a singleton (`AppDatabase()`); tests swap it via `AppDatabase.testInstance` / `AppDatabase.forTesting(executor)`. To change the schema, add the table to the `@DriftDatabase` list, bump `schemaVersion` (currently 33) and add an `if (from < N) { try { ... } catch (_) {} }` block to `onUpgrade` in `app_database.dart` (existing blocks swallow errors so re-running is idempotent), then rerun build_runner.

### Mushrooms module (`lib/modules/mushrooms/`)
The main product vertical on this branch (Costa Mushrooms: ~66 grow rooms across Plant M1/M2, daily job plans, harvest planning, attendance/timesheets, Solo-Job safety + radio gateway, purchasing, 3D room view). Shape: `mushrooms_module.dart` (manifest + AI `AgentTool`s, some with `requiresConfirmation`) → `bloc/mushrooms_bloc.dart` → `repository.dart` (one large class that owns all Drift access and enqueues sync mutations via `SyncService`) with domain logic split into `services/*` (employee, harvest plan + Excel import, job list, PDF export, safety, radio gateway, etc.) and `screens/*` tabs. UI strings and many comments are Vietnamese. Room IDs are deterministic (`'Room 6A'` → `room_6a`) so seeds converge across devices — preserve that when touching seeding.

### Device identity, enrollment & security
- `lib/core/device_identity/` — device identity, BLE discovery of nearby devices, and a Noise-protocol-style handshake (`noise_handshake_service.dart`) plus `crypto_service.dart` for key management.
- `lib/core/enrollment/` — onboarding new devices onto a server via QR/NFC-issued enrollment tickets (`enrollment_service.dart`, `nfc_enrollment_service.dart`), mirrors the server's `/devices/enroll` flow.
- `lib/core/security/` — `ble_p2p_handshake_service.dart` (BLE pairing crypto) and `image_key_kdf_engine.dart` (key derivation for encrypted image storage).
- `lib/core/community/` — invite flow, trust scoring/matching engine, and trust-network graph used to gate community features.

### AI Agent
`lib/core/ai_agent/` implements a tool-calling chat agent: `ai_agent_service.dart` orchestrates calls through a pluggable `llm_provider.dart` interface (currently `gemini_provider.dart` backed by `google_generative_ai`), `tools/agent_tool_registry.dart` collects `AgentTool`s contributed by each installed module (see `IZiiModule.agentTools`), and `bloc/chat_bloc.dart` drives the chat UI. This is how modules expose "let the AI do X" capabilities without the agent needing hardcoded knowledge of each module.

## Python server architecture (`server/`)

- `app.py` — FastAPI app entrypoint. Boots the DB (`db_init.py`), runs versioned SQL migrations (`migrations/runner.py`, files in `migrations/versions/`), loads declarative seed data (`seeds/seed_loader.py`), initializes server-side business modules (`modules/module_manager.py`, manifests in `modules/{core,collab,field_ops,workforce}/manifest.json`), starts mDNS advertise/discovery (`server_discovery.py`) for LAN peer auto-detection, and launches background asyncio loops for peer-to-peer delta sync and daily maintenance (pruning old mutations/dead-letter messages).
- `routers/` — one module per API surface: `sync` (device push/pull mutation log), `devices`, `messages`/`notifications`/`attachments`, `peer_sync` (server-to-server delta replication for the multi-server mesh), `call`, `webhooks`, `admin` (privileged reset/config, gated by `X-iZii-Admin-Token`), `enrollment` (public, gated by invite ticket), `sessions` (shift check-in/attendance).
- `repository/` — repository-pattern data access with an `interface.py` contract and two implementations, `sqlite_repo.py` (default) and `postgres_repo.py` (opt-in via `IZIIAPP_DB_BACKEND=postgres` for multi-writer/multi-site scale — see `HUONG_DAN_CHUYEN_DATABASE_POSTGRES.md` / `POSTGRES_MIGRATION_GUIDE.md`).
- `dependencies.py` — FastAPI DI: opens DB connections and constructs the right repo implementation based on config.
- **Auth model has three separate secrets** (`server/.env.example` is authoritative): `IZIIAPP_SERVER_SECRET` (server↔server peer sync), `IZIIAPP_ADMIN_SECRET` (`/admin/*`, never given to worker devices), and per-device tokens issued via enrollment (`/sync/*`). WebSocket `/chat` requires `IZIIAPP_WS_SECRET` (falls back to `IZIIAPP_SERVER_SECRET`); with neither set, `/chat` refuses all connections. Do not conflate these when adding new endpoints.
- **Multi-server mesh**: each server has a `server_id`/`zone`; `_peer_sync_loop` in `app.py` pulls deltas from both statically-configured peers (`IZIIAPP_PEERS`) and mDNS-discovered peers, tracked by a monotonic `after_seq` cursor (deliberately not wall-clock time, to avoid skew-related data loss) persisted per-peer in `known_servers`.
- **Security tests double as the spec**: `server/tests/test_phase1_foundation.py`, `test_phase2_module_system.py`, `test_phase5_business_gate.py`, `test_phase0_security_regression.py`, and `test_p0_10_security_e2e.py` encode the intended behavior for audit fields, RLS/multi-tenancy, migrations, seeds, and the three-secret auth model — consult them before changing auth or schema behavior.
- **Mutation log → read model**: devices push mutations into `sync_mutations`; `projector.py` projects them into normalized relational tables (logical→physical names in `TABLE_ALIASES`, e.g. `jobs` → `mushroom_jobs`; per-column "dirty-field" merge; extensible via `hooks.py`) — primarily for the PostgreSQL backend. `event_engine.py` maps table mutations to domain events and broadcasts them over WebSocket / outbound webhooks. When adding a synced entity, you generally need: a Drift table + repository mutation on the client, a SQL migration in `migrations/versions/` (next number after `0011_*`), and a `TABLE_ALIASES` entry.
- Mushroom/field-ops specific routers: `radio_gateway.py`, `agv_gateway.py`, `workforce.py`, `sessions.py`; `services/timesheet_service.py` computes daily timesheets. `server/flutter/` holds client-side server-selection/discovery code kept next to the server.
- `sync_server.py` at the repo root is a legacy standalone prototype of the sync server; the real server is `server/app.py`.
- Distributed as a PyInstaller-frozen executable (`izii_server.spec`) so the Flutter desktop build can bundle it; `server_config.py` includes a port-guard that refuses to start if the target port is already in use.

## Notes for working in this repo

- Many top-level `*.md`/`*.txt` files (`walkthrough.md`, `implementation_plan*.md`, `debug_UI.txt`, design docs) are working notes/specs from prior sessions, not authoritative documentation — prefer reading the code itself.
- A large amount of server-side commentary and some client comments are written in Vietnamese explaining non-obvious *why* (e.g. clock-skew reasoning in peer sync, secret-scope separation rationale) — read them, they usually contain the real constraint behind a design decision.
- `server/venv/`, `server/build/`, `server/dist/`, `build/`, `.dart_tool/` are build artifacts/vendored envs — never hand-edit.
