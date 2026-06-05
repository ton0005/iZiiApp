# iZiiApp — Phase 1 Task Tracker

## Environment Setup
- [x] Install Flutter SDK
- [x] Add Flutter to PATH
- [x] Create Flutter project `izii_app`
- [x] Configure pubspec.yaml with dependencies

## 1. Core App Shell & Theme
- [x] `lib/main.dart` — Entry point
- [x] `lib/app.dart` — MaterialApp + GoRouter
- [x] `lib/core/theme/izii_colors.dart` — Brand colors
- [x] `lib/core/theme/izii_theme.dart` — Dark/Light themes
- [ ] `lib/core/theme/izii_typography.dart` — Typography
- [ ] `lib/core/theme/izii_spacing.dart` — Spacing tokens
- [x] `lib/core/navigation/app_router.dart` — Router
- [ ] `lib/core/widgets/` — Reusable components

## 2. Database Engine (Drift)
- [x] `lib/core/database/app_database.dart` — Main DB
- [x] `lib/core/database/tables/` — Core tables
- [x] `lib/core/database/daos/` — DAOs
- [x] Run `build_runner` to generate code
- [x] Refactor Repositories (CRM, Supply Chain & Services) to use AppDatabase and SyncService mutations

## Phase 3: Drift SQLite Implementation
- [x] Create `AppDatabase` schema and DAOs (Users, Contacts, Leads, Deals, Products, StockMoves).
- [x] Run `build_runner` to generate Drift code.
- [x] Refactor `CrmRepository` to use `AppDatabase` instead of `mockLeads`.
- [x] Refactor `InventoryRepository` to use `AppDatabase` instead of `mockProducts`.
- [x] Refactor screens (`AddLeadScreen`, `EditLeadScreen`, `AddProductFromImageScreen`, `EditProductScreen`) to `await` asynchronous database calls.

## Phase 4: Community Layer (Trust & Referral)
- [x] Define Community Models (`UserProfile`, `ServiceListing`, `Order`).
- [x] Implement Community Database Tables (`TrustScores`, `Referrals`, `ServiceListings`, `Orders`) and run `build_runner`.
- [x] Implement `TrustNetworkService` (Trust graph and scoring).
- [x] Implement `InviteService` (Referral system).
- [x] Implement `MatchingEngine` (Service provider matching).
- [x] `lib/core/ai_agent/models/chat_models.dart`
- [x] `lib/core/ai_agent/llm_providers/llm_provider.dart`
- [x] `lib/core/ai_agent/tools/agent_tool_registry.dart`
- [x] `lib/core/ai_agent/ai_agent_service.dart`
- [x] `lib/core/ai_agent/ai_tool_router.dart`
- [x] `lib/core/ai_agent/ai_tool_executor.dart`
- [ ] `lib/core/ai_agent/llm_providers/openai_provider.dart`
- [ ] `lib/core/ai_agent/llm_providers/ondevice_provider.dart`
- [x] `lib/core/ai_agent/ui/ai_chat_screen.dart`
- [x] `lib/core/ai_agent/ui/ai_message_bubble.dart`

## 4. Community Layer
- [ ] `lib/core/community/trust_network_service.dart`
- [ ] `lib/core/community/trust_score_calculator.dart`
- [ ] `lib/core/community/matching_engine.dart`
- [ ] `lib/core/community/invite_service.dart`
- [x] `lib/core/community/models/community_models.dart`

## 5. Module Manager
- [x] `lib/core/modules/module_interface.dart` — iZiiModule
- [x] `lib/core/modules/module_manifest.dart`
- [x] `lib/core/modules/module_registry.dart`
- [ ] `lib/core/modules/dependency_graph.dart`
- [ ] `lib/core/modules/module_installer.dart`

---

## Phase 5: Core Screens
- [ ] Implement `DiscoverScreen` (Search, Filters, Matching Engine UI).
- [ ] Implement `ProviderCard` for displaying matched services.
- [ ] Implement `ProfileScreen` (User info, Trust Score, Referrals).
- [ ] Implement `OnboardingScreen` (KYC status and setup).

## Phase 6: Modules — Next Steps

Expand and complete the Sales/CRM and Supply Chain modules, plus integration and QA tasks.

### 6. Sales & CRM Module
- [x] `lib/modules/sales_crm/manifest.dart`
- [x] `lib/modules/sales_crm/sales_crm_module.dart`
- [x] `lib/modules/sales_crm/database/tables.dart`
- [x] `lib/modules/sales_crm/models/`
- [x] `lib/modules/sales_crm/agent_tools/crm_tools.dart`
- [x] `lib/modules/sales_crm/bloc/`
- [x] `lib/modules/sales_crm/screens/`
- [x] `lib/modules/sales_crm/daos/` — implement DAOs for Leads, Contacts, Deals
- [x] `lib/modules/sales_crm/repository.dart` — repository adapter using `AppDatabase`
- [x] `lib/modules/sales_crm/services/crm_service.dart` — business logic and sync hooks
- [ ] `lib/modules/sales_crm/ui/lead_form.dart` — add/edit lead UI and validation
- [ ] `lib/modules/sales_crm/ui/deal_pipeline.dart` — Kanban/list view
- [ ] Tests: unit tests for DAOs + widget tests for screens
- [ ] Docs: `modules/sales_crm/README.md` (API, data model, integration)
- [ ] Integrate with `ModuleRegistry` and enable lazy loading

### 7. Supply Chain Module
- [x] `lib/modules/supply_chain/manifest.dart`
- [x] `lib/modules/supply_chain/supply_chain_module.dart`
- [x] `lib/modules/supply_chain/database/tables.dart`
- [x] `lib/modules/supply_chain/agent_tools/`
- [x] `lib/modules/supply_chain/screens/`
- [x] `lib/modules/supply_chain/daos/` — implement DAOs for Products, StockMoves, Warehouses
- [x] `lib/modules/supply_chain/repository.dart` — repository adapter using `AppDatabase` and SyncService

### 8. Services Module (Scheduling & Appointments)
- [x] `lib/modules/services/manifest.dart`
- [x] `lib/modules/services/services_module.dart`
- [x] `lib/modules/services/database/tables.dart` — ServiceItems & ServiceBookings tables created
  - `ServiceItems` table: id, name, category (repair, installation, delivery, cleaning, electrical, plumbing), hourlyRate, estimatedHours, description, customFields
  - `ServiceBookings` table: id, serviceItemId, customerName, customerPhone, scheduledAt, actualHours, totalAmount, status (pending, confirmed, in_progress, completed, cancelled), notes, customFields
- [x] `lib/modules/services/daos/` — DAOs implemented
  - `service_items_dao.dart` — CRUD for services (get all, get by category, insert, update, delete)
  - `service_bookings_dao.dart` — CRUD for appointments/bookings
- [x] `lib/modules/services/repository.dart` — repository adapter using `AppDatabase` and SyncService
  - `getServiceItems()` — list all services
  - `getServiceItemsByCategory()` — filter by category
  - `addServiceItem()` — add new service
  - `getServiceBookings()` — list appointments by status/date
  - `createBooking()` — schedule appointment
  - `updateBookingStatus()` — update appointment status
- [/] `lib/modules/services/agent_tools/` — AI tools partially implemented
  - `get_service_info` — tra cứu thông tin dịch vụ (needs integration with repository)
  - TODO: `schedule_service_tool` — create appointments via AI
  - TODO: `get_service_availability_tool` — check available slots
  - TODO: `update_service_booking_tool` — modify existing bookings
- [x] `lib/modules/services/screens/`
  - `services_screen.dart` — list available services with category filter
  - `bookings_screen.dart` — list scheduled appointments
  - `add_service_screen.dart` — form to add new service
  - `edit_service_screen.dart` — edit existing service
  - `add_booking_screen.dart` — schedule appointment form
- [x] `lib/modules/services/bloc/` — state management
  - `services_bloc.dart` — ServicesBLoC with events/states for CRUD operations
- [x] Integration with `ModuleRegistry` — ServicesModule registered and lazy loaded
- [ ] Test suite — unit tests for DAOs, repository, and widget tests for screens
- [ ] API Documentation — `modules/services/README.md`
- [ ] `lib/modules/supply_chain/services/stock_service.dart` — inventory adjustments, reservations
- [ ] `lib/modules/supply_chain/ui/stock_management.dart` — stock list, receiving, transfer flows
- [ ] `lib/modules/supply_chain/integration/order_fulfillment.dart` — connect with Sales module
- [ ] Tests: unit tests for DAOs + integration tests for stock flows
- [ ] Docs: `modules/supply_chain/README.md`
- [ ] Integrate with `ModuleRegistry` and add dependency edges (e.g., sales -> supply_chain)

### Module Integration & QA
- [ ] Contract tests between modules (data shapes, events)
- [ ] End-to-end smoke: create lead -> convert to order -> reserve stock

## 6. Sync Engine
- [x] `lib/core/sync/sync_service.dart`
- [x] `lib/core/sync/outbox_queue.dart`
- [ ] `lib/core/sync/conflict_resolver.dart` — implement pluggable resolvers (last-write, merge, manual)
- [ ] `lib/core/sync/sync_scheduler.dart` — background / periodic sync with exponential backoff
- [ ] `lib/core/sync/delivery_guarantees.md` — document at-least-once vs exactly-once expectations
- [x] Integration: test sync across modules (sales_crm, supply_chain, services)

## 7. Auth & Settings
- [ ] `lib/core/auth/auth_service.dart`
- [ ] `lib/core/settings/settings_screen.dart`
- [ ] `lib/core/settings/ai_config_screen.dart`

## 8. Feature Screens
- [x] `lib/features/home/home_screen.dart`
- [ ] `lib/features/discover/discover_screen.dart`
- [ ] `lib/features/onboarding/onboarding_screen.dart`
- [ ] `lib/features/profile/profile_screen.dart`

## Verification
- [ ] `flutter run -d windows` works
- [ ] Core navigation functional
- [ ] AI Chat screen renders
- [ ] Module Manager lists available modules
