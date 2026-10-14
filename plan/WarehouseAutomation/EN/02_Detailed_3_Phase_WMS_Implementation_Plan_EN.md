# DETAILED 3-PHASE WMS IMPLEMENTATION PLAN FOR IZIÍAPP
## Roadmap to Transform iZiiApp into an Industrial-Grade WMS & Intralogistics Platform

---

| Parameter | Specification |
| :--- | :--- |
| **Project** | iZiiApp Industrial Warehouse Management System (iZiiApp WMS) Upgrade |
| **Objective** | Build an enterprise-grade WMS, SCM, and shop-floor intralogistics platform natively engineered for Offline-First edge environments |
| **Benchmark Facility** | Costa Mushroom (Plant M1 & M2, 60 tonnes/day peak harvest volume) |
| **Project Timeline** | 18 Weeks (3 Phases, 9 Sprints × 2 Weeks/Sprint) |
| **File Location** | `plan/WarehouseAutomation/02_Detailed_3_Phase_WMS_Implementation_Plan_EN.md` |

---

## 1. EXECUTIVE ROADMAP (18-WEEK OVERVIEW)

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              18-WEEK EXECUTIVE ROADMAP                                 │
└────────────────────────────────────────────────────────────────────────────────────────┘

 [ Weeks 1 - 6 ]     PHASE 1: CORE WMS FOUNDATION & PALLETIZATION DIGITALIZATION
 ────────────────    • Schema Refactoring: Locations hierarchy, Multi-UoM conversion.
                     • Pallet License Plate Numbers (LPN) & Batch/Expiry tracking (StockLots).
                     • Pallet Scale Station screen & Industrial GS1 handheld/forklift UI.
                     • StockQuants overhaul with location constraints & Picking lifecycle.

 [ Weeks 7 - 12 ]    PHASE 2: SHOP-FLOOR INTRALOGISTICS, PUTAWAY, FEFO & AUDITING
 ────────────────    • Closed-loop Harvest MES-to-Cold Store integration (Auto-Batch creation).
                     • 3D Directed Putaway Algorithm based on volume, weight, and ABC velocity.
                     • Automated FEFO / FIFO Outbound Inventory Allocation Engine.
                     • Inbound/Harvest Quality Control Gates (QC Quarantine/Approval).
                     • Perpetual Blind Cycle Counting without manufacturing shutdowns.

 [ Weeks 13 - 18 ]   PHASE 3: WAVE PICKING, IN-TRANSIT COLD-CHAIN & DIGITAL FLEET DISPATCH
 ────────────────    • Wave & Batch Picking Engine with S-Shape aisle path optimization.
                     • Packout verification station with inline scale gross weight auditing.
                     • Truck in-transit cold-chain temperature telemetry via BLE loggers.
                     • Electronic Proof of Delivery (e-PoD) with signature capture and GPS.
                     • Standardized AGV/AMR robot dispatching gateway (VDA 5050 protocol).
```

---

## 2. PHASE 1: CORE WMS FOUNDATION & PALLETIZATION DIGITALIZATION (WEEKS 1 – 6)

### 2.1 Key Objectives
* Eliminate arbitrary string location identifiers; enforce foreign key relationships against the hierarchical `Locations` tree.
* Implement multi-tier Unit of Measure (**Multi-UoM**) packaging configurations.
* Establish **Pallet License Plate Numbers (LPN)**, **Batch/Lot lifecycle management**, and automated **GS1-128 / GS1 DataMatrix** barcode parsing.
* Deliver high-contrast, touch-optimized user interfaces for scale packout stations and forklift-mounted terminals.

### 2.2 Sprint Breakdown

#### Sprint 1 (Weeks 1 - 2): Database Architecture & Data Layer Overhaul (Drift & Postgres)
* **Backend Migration & Schema Updates**:
  1. Author server migration script `server/migrations/versions/0010_industrial_wms_foundation.sql`:
     * `product_uoms`: Define base units and conversion factors (`ratio_to_base`).
     * `product_packagings`: Define packaging geometry (L × W × H, tare weight, boxes per layer, boxes per pallet).
     * `stock_lots`: Lot numbers, production date, expiration date (`expiry_date`), quarantine state (`quarantine`, `approved`, `blocked`).
     * `stock_lpns`: LPN identifier, current `location_id`, measured `gross_weight_kg`, status (`staged`, `stored`, `in_transit`, `shipped`).
     * `stock_lpn_contents`: Manifest of items and lots assigned to an LPN.
  2. Overhaul `stock_quants`:
     * Add foreign key `location_id` referencing `locations(id)`.
     * Add `lot_id`, `lpn_id`, `reserved_qty`, `available_qty`.
     * Composite unique index: `UNIQUE(product_id, location_id, lot_id, lpn_id)`.
  3. Client-Side Drift Tables (`lib/modules/supply_chain/database/tables.dart`):
     * Replicate entities into Drift table definitions.
     * Execute code generator: `dart run build_runner build --delete-conflicting-outputs`.
* **Outbox Sync Pipeline Registration**:
  * Register new entities into the offline mutation queue (`sync_mutations`).

#### Sprint 2 (Weeks 3 - 4): Pallet LPN Management & Scale Packout Station
* **Business Logic & Services**:
  1. Implement `LpnService` (`lib/modules/supply_chain/services/lpn_service.dart`):
     * Standardized LPN generator: `generateLpnCode(zone, plant)`.
     * Pallet creation routines with item aggregations (`createPalletWithLines`).
     * Split and merge operations for partial pallet re-stacking.
  2. Implement `UomConverter` (`lib/core/utils/uom_converter.dart`):
     * Real-time bidirectional conversion between Cartons $\leftrightarrow$ Pallets $\leftrightarrow$ Kilograms.
* **User Interface & Peripheral Integration**:
  1. Build **Pallet Scale Station Screen** (`PalletScaleStationScreen`):
     * Tablet-optimized layout for packhouse floor workers.
     * Fast selection of mushroom grade (Button / Cup / Flat) and box type (Type 1 / Type 2).
     * Serial/Bluetooth RS-232 integration with floor bench scales for instantaneous tare and gross weight capture.
     * **"Finalize & Print LPN Label"** action: Atomically creates LPN record, sets staging location, and transmits ESC/POS ZPL print payload to Zebra/TSC thermal label printers over Wi-Fi/Bluetooth.

#### Sprint 3 (Weeks 5 - 6): Forklift Terminal UI & High-Speed GS1 Barcode Scanning
* **Industrial GS1 Barcode Parser**:
  * Build an offline parser for GS1-128 / DataMatrix symbologies: Extracts `(01)` GTIN, `(10)` Batch, `(17)` Expiry, and `(3102)` Weight.
* **Forklift Driver Terminal Interface (`ForkliftScanScreen`)**:
  * High-contrast, large-button mobile UI tailored for forklift mounts in condensation-heavy cold store environments.
  * Three-step operational flow:
    1. Scan **LPN Barcode** (Reads payload and current slot).
    2. Scan **Destination Location Barcode** (Rack slot or cold store intake).
    3. Press **Confirm Move**: Executes atomic SQLite transaction updating `StockQuants` and `StockMoves`, enqueuing mutations into the local Outbox Queue.
* **Phase 1 Quality Verification**:
  * Automated unit tests covering UoM conversion ratios and transactional LPN relocations.
  * 100-pallet offline stress test: Simulate full disconnection, execute rapid scans, reconnect, and verify zero data corruption on Postgres.

---

## 3. PHASE 2: SHOP-FLOOR INTRALOGISTICS, PUTAWAY, FEFO & AUDITING (WEEKS 7 – 12)

### 3.1 Key Objectives
* Bridge production harvest events (MES) directly into the finished goods cold store.
* Automate rack slotting via a **3D Directed Putaway Engine** adhering to weight and volume limits.
* Enforce automated outbound **FEFO (First Expired, First Out)** inventory allocation.
* Introduce an **Incoming Quality Control (QC) Gate** and continuous **Perpetual Blind Cycle Counting**.

### 3.2 Sprint Breakdown

#### Sprint 4 (Weeks 7 - 8): MES Harvest to Cold Store Closed-Loop Integration
* **Automated Yield Conversion**:
  1. Hook into `lib/modules/mushrooms` completion workflows:
     * When shift supervisors finalize picking runs in `MushroomHarvestPlans`, the system automatically creates inbound transfer orders (`StockPickings` with `type = 'incoming_harvest'`).
  2. Automated Lot Numbering (`StockLots`):
     * Dynamic format: `LOT-[HarvestDate]-[RoomCode]-[Grade]`.
     * Automatically computes Best Before (+5 days) and Expiry Date (+7 days) based on cold chain baseline standards ($2^\circ\text{C} - 4^\circ\text{C}$).
  3. Central Conveyor Line & Inbound Processing Workflow:
     * **Box Mover Staging**: Box Movers collect harvested mushroom boxes from room corridors and feed all individual boxes onto the central packhouse conveyor line located in the middle of the facility.
     * **Automated Inline Quality & Weight Telemetry**:
       - **Inline Metal Detector**: Inspects 100% of passing boxes for foreign metal contaminants; non-compliant boxes are diverted to a designated reject spur.
       - **AI Vision Camera Inspection**: Automatically captures surface imagery to verify mushroom grade/classification (Button, Cup, Flat), cap diameter distribution, and surface defect screening.
       - **Inline Box Check-Weigher**: Captures dynamic individual carton weights at line speed and automatically streams real-time weight records into the iZiiApp management software.
     * **Central Palletizing Station**:
       - Verified cartons downstream of the check-weigher are stacked onto standard Australian pallets (1165 × 1165 mm) at the central packing area.
       - Pallet License Plate Numbers (LPN barcodes) are generated and applied to identify the consolidated load.
     * **Forklift Transfer & Automated Airlock Scale Entry**:
       - Forklifts pick up completed pallets and transport them toward the cold store automated high-speed roll door.
       - **In-Floor Pallet Scale (Weighbridge)**: Full gross pallet weight is captured at the door threshold, cross-verifying total pallet load against the sum of upstream conveyor box weights.
       - Upon weight validation, the fast-action door opens automatically to admit the forklift into the cold store.

#### Sprint 5 (Weeks 9 - 10): 3D Directed Putaway & Automated FEFO Allocation
* **3D Directed Putaway Engine**:
  1. When a forklift operator scans an LPN at cold store intake, the system executes `calculateOptimalPutawayLocation(lpnId)`:
     * Filters active bins in `Locations` where `isStorable = true` and `status = 'active'`.
     * Verifies structural capacity: `current_weight + pallet_weight <= maxWeightKg` and `current_volume + pallet_volume <= maxVolumeM3`.
     * Heuristics:
       * Heavy pallets $\rightarrow$ Assigned to Level 1 floor positions.
       * Fast-moving SKUs $\rightarrow$ Assigned near primary thoroughfares and dock doors based on `Locations.path` and `depth`.
       * Affinity rules: Groups identical SKU/Lot pallets in adjacent bays.
  2. Forklift screen renders navigation arrows and the recommended slot target (e.g., `TARGET: WH1-COLD-A02-R01-L1`).
* **Automated Outbound FEFO Allocation Engine**:
  * When sales delivery orders are confirmed, the system triggers `allocateStockFefo(productId, requestedQty)`:
    * Queries `StockQuants` where `lot.status = 'approved'` and `available_qty > 0`.
    * Sorts deterministically: `ORDER BY stock_lots.expiry_date ASC, stock_quants.quantity ASC`.
    * Reserves quantities (`reserved_qty += pick_qty`, `available_qty -= pick_qty`) to eliminate concurrent double-picking.

#### Sprint 6 (Weeks 11 - 12): Quality Control Gate (QC) & Perpetual Blind Cycle Counting
* **Quality Control Gate Workflow**:
  * Inbound packaging consignments and freshly harvested lots default to `quarantine`.
  * Deliver `QcInspectionScreen`:
    * Inspection checklist: Internal product temperature, surface moisture, discoloration, packaging integrity.
    * *Pass* $\rightarrow$ Updates lot status to `approved`, immediately enabling FEFO allocation.
    * *Fail* $\rightarrow$ Sets status to `blocked`, generating supervisor notifications and preventing outbound reservation.
* **Perpetual Blind Cycle Counting Module**:
  1. `cycle_count_sessions` and `cycle_count_lines`:
     * Schedule counts by zone or aisle without halting plant operations.
  2. Blind Count Mode:
     * Mobile terminal prompts operator to scan a location, then scan all present LPNs/cartons and enter physically counted quantities.
     * System completely hides expected system quantities from the screen.
  3. Discrepancy Reporting & Reconciliation:
     * Discrepancies generate variance reports; only Level 3 managers possess permissions to approve adjustments and commit `StockAdjustmentMove` updates.

---

## 4. PHASE 3: WAVE PICKING, IN-TRANSIT COLD-CHAIN & DIGITAL FLEET DISPATCH (WEEKS 13 – 18)

### 4.1 Key Objectives
* Maximize order fulfillment throughput via **Wave & Batch Picking**.
* Enforce packing validation with inline scale gross-weight auditing.
* Monitor truck refrigeration integrity in-transit using Bluetooth telemetry and execute digital deliveries with **e-PoD**.
* Expose a standardized **VDA 5050 Gateway** for Automated Guided Vehicles (AGVs) and cold room roll-door automation.

### 4.2 Sprint Breakdown

#### Sprint 7 (Weeks 13 - 14): Wave Picking & Check-Weighing Verification
* **Wave Picking Engine (`StockWave`)**:
  1. Consolidate multiple delivery orders bound for the same dispatch window into a single picking wave.
  2. Pick-Path Optimizer:
     * Traverses warehouse aisles using an optimized S-shape path derived from `Locations.path`.
     * Enables forklift drivers to retrieve items for all orders in a single continuous circuit.
* **Packout Scale Verification Station**:
  * Position digital scale check-stations at dock staging areas.
  * When pallets are scanned prior to container loading, the system compares actual scale weight against calculated theoretical BOM weight (tare + boxes + net weight).
  * If weight variance exceeds $\pm 1.5\%$, an audible alarm triggers and halts manifest generation until manual recount is completed.

#### Sprint 8 (Weeks 15 - 16): In-Transit Cold-Chain Telemetry & Mobile e-PoD
* **In-Transit Cold-Chain Telemetry**:
  1. Deploy rugged Bluetooth (BLE) temperature loggers inside refrigerated trailer bodies.
  2. Driver Mobile Interface:
     * Background service continuously polls logger beacons via `ble_sync_manager`.
     * Audio-visual alerts activate on the driver's phone if cargo temperature rises above critical limits ($> 5^\circ\text{C}$).
     * Upon destination arrival, the app downloads logged temperature curves and embeds compliance charts into the delivery manifest.
* **Electronic Proof of Delivery (e-PoD)**:
  * Driver mobile delivery screen:
    1. Displays delivery stop manifest.
    2. Captures photos of container security seals and cargo condition.
    3. Records customer digital signature directly on glass.
    4. Automatically stamps GPS coordinates and cryptographic timestamps.
    5. Flips status to `Delivered`, triggering immediate ERP billing synchronization.

#### Sprint 9 (Weeks 17 - 18): VDA 5050 AGV Gateway & End-to-End Plant Commissioning
* **Standardized AGV / AMR Gateway (VDA 5050)**:
  1. Implement FastAPI endpoint `server/routers/agv_gateway.py`:
     * Dispatches pallet transfer missions to AGV fleet controllers over MQTT/WebSocket using VDA 5050 format:
       * `orderId`: Unique stock move UUID.
       * `nodes`: Pickup and drop-off coordinates mapped from `Locations.posX, posY, posZ`.
     * Ingests AGV telemetry (`executing`, `succeeded`, `failed`) to automatically close picking moves.
* **Fast-Action Cold Store Door Interlock**:
  * Uses `AutomationRules` to interface with cold room roll-doors via IoT relays, opening doors only as authorized forklifts/AGVs approach.
* **End-to-End Factory Acceptance Testing (FAT)**:
  * Full-scale plant dry run:
    * *Harvest completion $\rightarrow$ Pallet packout at scale $\rightarrow$ Directed putaway to cold store $\rightarrow$ FEFO wave pick $\rightarrow$ Truck loading $\rightarrow$ In-transit BLE telemetry $\rightarrow$ e-PoD signoff*.
  * Multi-device offline stress test: 50 concurrent mobile terminals operating offline.

---

## 5. DELIVERABLES MATRIX & DEFINITION OF DONE

| Phase | Weeks | Focus Area | Technical Deliverable | Definition of Done (DoD) |
| :--- | :--- | :--- | :--- | :--- |
| **P1** | W1 - 2 | Core WMS Schema & Multi-UoM | Migration `0010_industrial_wms_foundation.sql`, Drift Tables `ProductUoms`, `StockLots`, `StockLpns`. | Codegen completes cleanly; migrations apply on SQLite & Postgres; outbox sync operational. |
| **P1** | W3 - 4 | Pallet Scale Station & LPN | `PalletScaleStationScreen`, `LpnService`, `UomConverter`, Bluetooth/Wi-Fi ESC/POS printer driver. | Pallet assembled, scale weight captured, GS1 label printed in $< 3$ seconds. |
| **P1** | W5 - 6 | Forklift Screen & GS1 Scan | `ForkliftScanScreen`, Industrial GS1-128 barcode parser. | Single-scan LPN + location move confirmed in $< 1$ second; 100% offline-ready. |
| **P2** | W7 - 8 | MES Harvest $\rightarrow$ Central Conveyor $\rightarrow$ Cold Store | Service linking `MushroomHarvestPlan` to `StockPickings`, auto-generation of `StockLots`, Conveyor telemetry drivers (Metal Detector, Vision AI, In-line Box Weigher, In-floor Pallet Scale). | Harvest completion triggers conveyor box data logging, pallet LPN generation, threshold scale verification, and automated door entry into cold store. |
| **P2** | W9 - 10 | Directed Putaway & Auto FEFO | `DirectedPutawayEngine`, `FefoAllocationEngine`. | Generates valid 3D slot recommendations; outbound orders reserve earliest expiry batches. |
| **P2** | W11 - 12| QC Gate & Blind Cycle Count | `QcInspectionScreen`, `BlindCycleCountScreen`, Variance Reconciliation report. | Quarantined lots blocked from outbound allocation; blind counting prevents book inventory leaks. |
| **P3** | W13 - 14| Wave Picking & Weight Check | `WavePickingBloc`, Staging packout gross-weight audit station. | Aggregates 20 orders into one optimized route; flags weight anomalies $> \pm 1.5\%$. |
| **P3** | W15 - 16| Cold-Chain Telemetry & e-PoD | BLE logger background reader, `DriverPodScreen` with signature & GPS capture. | Triggers audible cabin alarm on $> 5^\circ\text{C}$; successful signoff updates delivery status. |
| **P3** | W17 - 18| VDA 5050 AGV & E2E Validation| `agv_gateway.py` router, cold room door relay trigger, FAT commissioning report. | Dispatches test mission to AGV simulator; validates end-to-end flow from harvest to customer. |

---

## 6. RISK MANAGEMENT MATRIX

| # | Operational Risk | Severity | Potential Impact | Mitigation Strategy |
| :---: | :--- | :---: | :--- | :--- |
| **1** | Condensation and steam in deep cold rooms blur consumer phone camera lenses during barcode scans. | **High** | Scanning failures cause operational bottlenecks at intake. | Integrate industrial Bluetooth ring/handheld scanners (Zebra/Honeywell rugged units) via SPP/HID; format high-contrast, large-format GS1 DataMatrix labels. |
| **2** | Write conflicts when two forklift drivers simultaneously attempt to store pallets into the same empty slot during offline periods. | **Medium** | Over-allocation of single rack positions. | Implement optimistic soft-locking on the local server; client prompts second driver with immediate adjacent slot recommendation if collision occurs. |
| **3** | Human error during box stacking resulting in inaccurate carton counts per pallet. | **Medium** | Inventory quantity drift across downstream supply chain. | Enforce two-factor verification: barcode count tracking on the scale station coupled with automated gross weight validation against theoretical tare weight. |
| **4** | BLE temperature logger battery exhaustion during long-distance refrigerated transit. | **Low** | Loss of cargo temperature compliance data. | Utilize industrial loggers with 2+ year battery ratings; enforce pre-trip battery level checks (`batteryLevel > 20%`) before vehicles clear factory gates. |

---

## 7. NEXT STEPS & IMMEDIATE ACTION

This 18-week plan adheres to the **Evolutionary Architecture** principle, leveraging 100% of iZiiApp's existing investments (Drift, FastAPI, Offline Sync, IoT Automation) while safeguarding ongoing plant operations.

Upon authorization, the engineering team can initiate **Sprint 1** immediately by applying migration `0010_industrial_wms_foundation.sql` and defining the core `Multi-UoM`, `StockLots`, and `StockLpns` Drift tables.
