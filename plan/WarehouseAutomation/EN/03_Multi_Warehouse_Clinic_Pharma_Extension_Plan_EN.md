# MULTI-WAREHOUSE & CLINIC/PHARMA EXTENSION PLAN FOR IZIÍAPP WMS
## Architectural Blueprint & Domain Extension for Multi-Site Logistics & Healthcare GSP/GDP Compliance

---

| Item | Specification |
| :--- | :--- |
| **System** | iZiiApp Enterprise Modular Platform |
| **Extension Scope** | Multi-Warehouse Management & Clinic/Pharma GSP/GDP Compliance Layer |
| **Regulatory Standards** | GSP (Good Storage Practice), GDP (Good Distribution Practice), 21 CFR Part 11, GS1 Healthcare |
| **Reference Architecture** | `01_Logistics_Inventory_WMS_..._EN.md`, `02_Detailed_3_Phase_WMS_..._EN.md` |
| **Document Path** | `plan/WarehouseAutomation/03_Multi_Warehouse_Clinic_Pharma_Extension_Plan_EN.md` |

---

## 1. MULTI-WAREHOUSE ARCHITECTURAL DESIGN

### 1.1 Multi-Site Spatial Hierarchy
The iZiiApp WMS utilizes a **Dual Hierarchical Tree Model** (`Locations`: Adjacency List + Materialized Path) to represent distributed supply chain networks across unlimited physical warehouses without schema changes.

```
                           [CENTRAL SERVER / ENTERPRISE CLOUD]
                                           │
            ┌──────────────────────────────┴──────────────────────────────┐
            ▼                                                             ▼
    [PLANT / CENTRAL WAREHOUSE M1]                               [PLANT / REGIONAL HUB M2]
    (Zone: "plant_m1")                                           (Zone: "plant_m2")
    Path: /WH1                                                   Path: /WH2
    ├── /WH1/COLD (Finished Cold Store)                          ├── /WH2/MAIN (Primary Storage)
    ├── /WH1/DRY  (Dry Packaging Stores)                         └── /WH2/STAG (Receiving Staging)
    └── /WH1/RAW  (Raw Materials & Substrates)
            │                                                             ▲
            └───────────────── [INTER-WAREHOUSE TRANSFER] ────────────────┘
                              Virtual Location: /TRANSIT/TRUCK-01
```

* **Root Sites Topology**: Each facility, factory, or clinic branch is registered as a root node with `parentId = NULL` and `depth = 0` (e.g., `/WH1`, `/WH2`, `/CENTRAL-HUB`, `/CLINIC-HANOI`).
* **Multi-Warehouse Isolation & Rollup**:
  * Site-specific queries: `WHERE path LIKE '/WH1/%'`.
  * Enterprise-wide aggregate queries: `SELECT SUM(quantity) GROUP BY SUBSTRING(path, 1, 4)`.
* **Virtual In-Transit Locations**:
  * Outbound transfers between Facility A and Facility B allocate stock into a virtual in-transit node: `/TRANSIT/VEHICLE-XX`.
  * *Financial & Custody Integrity*: Source stock decreases, but corporate balance sheet inventory remains intact, securing 100% chain of custody during truck transit.

### 1.2 Inter-Warehouse Transfer Workflow
1. **Transfer Requisition**: Destination warehouse generates a replenishment request triggered by dynamic reorder points (Safety Stock).
2. **Origin Picking & Dispatch**:
   * Origin site executes automated FEFO allocation.
   * Pallet LPN or cartons are scanned out: Source `/WH1/COLD` $\rightarrow$ Destination `/TRANSIT/TRUCK-01`.
   * Transfer order status: `in_transit`.
3. **In-Transit Integrity**: Vehicle BLE loggers capture ambient cargo temperatures, alerting drivers if cooling units fail.
4. **Destination Receiving & Directed Putaway**:
   * Destination site scans inbound LPNs: Source `/TRANSIT/TRUCK-01` $\rightarrow$ Destination `/WH2/STAGING`.
   * **3D Directed Putaway** triggers immediately on the destination server, routing the pallet to the optimal rack position.

---

## 2. CLINIC & PHARMA COMPLIANCE EXTENSION

### 2.1 Regulatory Compliance Matrix

| Healthcare Standard | Operational Challenge | iZiiApp WMS Architectural Solution |
| :--- | :--- | :--- |
| **GSP (Good Storage Practice)** | Continuous 24/7 temperature monitoring (2°C - 8°C for biologics/vaccines, 15°C - 25°C for general pharmaceuticals). | Uses `IotDevices` and `SensorReadings`: real-time sirens, automated lot quarantine (`quarantine`) on temperature excursion events. |
| **21 CFR Part 11 (Audit Trail)** | Immutable audit records; strict prohibition against modifying or overwriting historical transactions. | Append-only database design; all stock reconciliations mandate structured reason codes (`reason_code`) and SHA-256 cryptographic signatures. |
| **GS1 Serialization** | Anti-counterfeit compliance: tracking unique serial numbers down to individual drug cartons/vials. | Introduces `StockSerialNumbers`: parses GS1 DataMatrix containing `(01) GTIN` + `(10) Lot` + `(17) Expiry` + `(21) Serial Number`. |
| **Controlled Substances & Narcotics** | Strict legal custody; zero tolerance for unauthorized dispensing. | **Dual Authorization (4-Eyes Principle)**: Mandates dual cryptographic authentication (Lead Pharmacist + Attending Physician) before controlled stock release. |
| **Bedside Dispensing Safety** | Dispensing errors present severe patient life-safety risks. | **"5 Rights" Barcode Verification**: Scan patient ID wristband $\rightarrow$ Scan prescription barcode $\rightarrow$ Scan drug unit serial number for 100% bedside cross-match. |

---

### 2.2 Hospital & Clinic Location Topology
The hierarchical `Locations` schema models complex hospital ward structures effortlessly:

```
/HOSPITAL-01
├── /CENTRAL_PHARMACY               (Central Pharmacy Store)
│   ├── /QUARANTINE_AREA            (Quarantine area pending lab release)
│   ├── /COLD_STORAGE_2_8C          (Biologics & Vaccine Cold Room)
│   ├── /CONTROLLED_DRUGS_VAULT     (High-security narcotics vault)
│   └── /GENERAL_DISPENSARY         (Outpatient pharmacy counter)
├── /EMERGENCY_DEPT                 (Emergency Department)
│   ├── /CRASH_CART_01              (Emergency resuscitation crash cart #1)
│   └── /BEDSIDE_CABINET_ROOM_101   (Patient bedside medication cabinet)
└── /OPERATING_THEATRE_SUITE        (Surgical block)
    └── /ANESTHESIA_CART_OR2        (Operating Room #2 Anesthesia Cart)
```

---

## 3. EXTENDED PHARMA DATA SCHEMA

The foundational Drift and Postgres database layers are extended with dedicated healthcare entities:

```sql
-- 1. Item Serialization Table (GS1 DataMatrix anti-counterfeiting)
CREATE TABLE IF NOT EXISTS stock_serial_numbers (
    id             TEXT PRIMARY KEY,
    product_id     TEXT NOT NULL,
    lot_id         TEXT NOT NULL,
    serial_number  TEXT NOT NULL UNIQUE,     -- Unique unit serial number
    location_id    TEXT NOT NULL,
    status         TEXT DEFAULT 'available', -- available, reserved, dispensed, destroyed, recalled
    created_at     TEXT,
    updated_at     TEXT
);

CREATE INDEX IF NOT EXISTS idx_serials_lot ON stock_serial_numbers(lot_id);
CREATE INDEX IF NOT EXISTS idx_serials_sn ON stock_serial_numbers(serial_number);

-- 2. Dual Authorization Sign-Off for Controlled Substances (4-Eyes Principle)
CREATE TABLE IF NOT EXISTS pharma_controlled_approvals (
    id                 TEXT PRIMARY KEY,
    picking_line_id    TEXT NOT NULL,
    product_id         TEXT NOT NULL,
    authorized_by_1    TEXT NOT NULL, -- Pharmacist-in-charge (User ID)
    signature_1        TEXT NOT NULL, -- Digital signature / auth PIN
    timestamp_1        TEXT NOT NULL,
    authorized_by_2    TEXT NOT NULL, -- Attending Physician / Dept Head (User ID)
    signature_2        TEXT NOT NULL,
    timestamp_2        TEXT NOT NULL,
    reason_notes       TEXT,
    created_at         TEXT
);

-- 3. Bedside Dispensing Log (Five Rights of Medication Administration)
CREATE TABLE IF NOT EXISTS pharma_dispensing_logs (
    id                 TEXT PRIMARY KEY,
    prescription_id    TEXT NOT NULL,
    patient_id         TEXT NOT NULL,
    patient_barcode    TEXT NOT NULL, -- Scanned from patient wristband
    product_id         TEXT NOT NULL,
    lot_id             TEXT NOT NULL,
    serial_number_id   TEXT,
    dispensed_qty      REAL NOT NULL,
    dispensed_by       TEXT NOT NULL, -- Dispensing nurse ID
    verified_at        TEXT NOT NULL
);
```

---

## 4. PURCHASING (PO) TO MULTI-WAREHOUSE INBOUND INTEGRATION

### 4.1 End-to-End Procurement-to-Storage Pipeline
The integration connects `PurchaseOrders` / `PurchaseOrderLines` directly to the industrial WMS receiving workflow, ensuring that raw materials, packaging, and agricultural chemicals ordered through purchasing automatically transition into inbound receipts (`stock_pickings`), quarantine gates, and directed multi-warehouse putaway.

```
 [PURCHASING (PO)]
  Status: approved
  Lines: Prochloraz, Chlorine, Sodium Hypochlorite, Peat Moss...
       │
       ▼ (Vendor Delivery / ASN Inbound)
 [INBOUND DOCK RECEIVING: WH-RAW / WH-CHEM]
  • Generate Inbound Picking: picking_type = 'incoming', origin = 'PO-2026-XXXX'
  • Scan Supplier Delivery Note / GS1-128 Barcodes
  • Capture Batch/Lot Number, Expiry Date, Drum/Pail Net Weight
       │
       ├────────────────────────────────────────┐
       ▼ (General Materials / Peat)             ▼ (Hazardous / Agricultural Chemicals)
 [STANDARD DIRECTED PUTAWAY]             [CHEMICAL SAFETY & HAZMAT PROTOCOL]
  • Putaway into /WH1/RAW or /WH2/MAIN    • Mandatory Safety Data Sheet (SDS) Verification
  • Standard pallet rack bay              • Bunded Spill Containment Verification
                                          • Chemical Incompatibility Matrix Isolation
                                          • Dual-Key Authorization for Toxic Fungicides
                                          • Putaway into /WH1/CHEM (Ventilated Hazmat Vault)
       │                                        │
       └──────────────────┬─────────────────────┘
                          ▼
              [STATUS: PO RECEIVED & POSTED]
               • PurchaseOrder.status = 'received'
               • StockQuants & StockLpns created (status: 'stored')
               • Automated ERP Accountant Journal Entry (Dr Inventory / Cr Accounts Payable)
```

---

### 4.2 Chemical Products & Hazmat Specifications

Mushroom farming and agricultural facilities require strict chemical segregation for fungicides, disinfectants, and sanitizers:

| Chemical Category | Representative Products | Primary Active Ingredient | Storage Warehouse / Zone | Mandatory Storage Constraints |
| :--- | :--- | :--- | :--- | :--- |
| **Agricultural Fungicides** | *Prochloraz (Octave / Sporgon)*, *Carbendazim* | Imidazole / Triazole fungicide | `/WH1/CHEM/FUNGICIDES` | Dry, ventilated, temperature-controlled (15°C - 25°C), locked cabinet, strictly isolated from mushroom spawn & casing peat. |
| **Water Sanitizers & Oxidizers** | *Sodium Hypochlorite (Chlorine 12.5%)*, *Calcium Hypochlorite* | Chlorine / Hypochlorite donor | `/WH1/CHEM/OXIDIZERS` | **Strict Separation from Acids & Organics**. Bunded spill containment pallet (110% drum capacity), UV protected, vented caps. |
| **Surface Disinfectants** | *Peracetic Acid (PAA)*, *Quaternary Ammonium (QAC)* | Organic peroxide / Quat salt | `/WH1/CHEM/DISINFECTANTS` | Separate spill bund; dedicated eyewash station within 10 meters; secondary containment. |
| **Post-Harvest Sanitizers** | *Food-Grade Chlorine Dioxide*, *Ozone wash salts* | Halogen oxidant | `/WH1/CHEM/POST_HARVEST` | Food contact grade compliance, separate lot quarantine until COA (Certificate of Analysis) sign-off. |

---

### 4.3 Chemical Incompatibility Matrix & Automated Bin Putaway Rules

The 3D Directed Putaway Engine (`DirectedPutawayEngine`) is extended with **Hazmat Segregation Rules**:

```
                       [HAZMAT INCOMPATIBILITY MATRIX]
                ┌───────────────────┬──────────────┬──────────────┬──────────────┐
                │ Chemical Category │ Oxidizers/Cl │ Acids/Peracid│ Fungicides   │
                ├───────────────────┼──────────────┼──────────────┼──────────────┤
                │ Oxidizers (Chlor) │      OK      │  🚨 PROHIBIT │  ⚠️ SEPARATE  │
                │ Acids / PAA       │  🚨 PROHIBIT │      OK      │  ⚠️ SEPARATE  │
                │ Fungicides (Proch)│  ⚠️ SEPARATE │  ⚠️ SEPARATE │      OK      │
                │ Finished Mushroom │  🛑 BANNED   │  🛑 BANNED   │  🛑 BANNED   │
                └───────────────────┴──────────────┴──────────────┴──────────────┘
```

1. **Rule CHEM-01 (Strict Isolation from Food)**: Under no circumstances can any chemical product (`type = 'chemical'`) be assigned to `/WH1/COLD` or any location containing fresh produce or mushroom packaging.
2. **Rule CHEM-02 (Acid-Chlorine Separation)**: Chlorine/Hypochlorite containers cannot share a rack bay or adjacent aisle with acid-based cleaners (prevents deadly Chlorine gas $Cl_2$ generation). Minimum physical distance: 5 meters or fire-rated firewall barrier.
3. **Rule CHEM-03 (Secondary Containment / Bunding)**: Liquid chemical drums must be put away only onto bins tagged with `has_spill_bund = true`.
4. **Rule CHEM-04 (Dual-Signoff on Toxic Fungicides)**: Fungicides containing Prochloraz mandate dual-authorization sign-off (`pharma_controlled_approvals`) prior to dispatch to growing rooms.

---

### 4.4 Data Model Extensions for PO & Chemical Receiving

```sql
-- 1. Chemical Specification Extension for Products
ALTER TABLE products ADD COLUMN IF NOT EXISTS hazard_class TEXT DEFAULT 'none'; -- none, toxic_fungicide, oxidizer, corrosive_acid, flammable
ALTER TABLE products ADD COLUMN IF NOT EXISTS un_number TEXT;                    -- UN Number (e.g. UN 1791 for Hypochlorite)
ALTER TABLE products ADD COLUMN IF NOT EXISTS sds_url TEXT;                      -- URL/Path to Safety Data Sheet (SDS)
ALTER TABLE products ADD COLUMN IF NOT EXISTS requires_bunding BOOLEAN DEFAULT FALSE;
ALTER TABLE products ADD COLUMN IF NOT EXISTS storage_temp_min REAL;
ALTER TABLE products ADD COLUMN IF NOT EXISTS storage_temp_max REAL;

-- 2. Purchase Order Inbound Receiving Link
ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS destination_warehouse_id TEXT; -- Root site (e.g. 'WH1', 'WH2')
ALTER TABLE purchase_order_lines ADD COLUMN IF NOT EXISTS product_id TEXT;
ALTER TABLE purchase_order_lines ADD COLUMN IF NOT EXISTS received_quantity REAL DEFAULT 0.0;
ALTER TABLE purchase_order_lines ADD COLUMN IF NOT EXISTS lot_id TEXT;
ALTER TABLE purchase_order_lines ADD COLUMN IF NOT EXISTS lpn_id TEXT;

-- 3. Chemical Spill & Inspection Audit Log
CREATE TABLE IF NOT EXISTS chemical_safety_logs (
    id                 TEXT PRIMARY KEY,
    product_id         TEXT NOT NULL,
    lot_id             TEXT NOT NULL,
    location_id        TEXT NOT NULL,
    inspector_id       TEXT NOT NULL,
    sds_verified       BOOLEAN DEFAULT TRUE,
    packaging_intact   BOOLEAN DEFAULT TRUE,
    bund_tested        BOOLEAN DEFAULT TRUE,
    eye_wash_verified  BOOLEAN DEFAULT TRUE,
    action_status      TEXT DEFAULT 'passed', -- passed, quarantine_hold, rejected
    notes              TEXT,
    created_at         TEXT NOT NULL
);
```

---

### 4.5 Inbound PO Receiving & Chemical Putaway Screen Flow

1. **PO Inbound Selection**:
   - Operator opens `PurchaseOrderReceivingScreen`.
   - Filters pending approved POs for the current warehouse (`destination_warehouse_id = 'WH1'`).
2. **Scan & Inspection**:
   - Scan supplier drum/carton barcode or manual entry.
   - For chemicals (Prochloraz, Chlorine): Form prompts for **Supplier Lot Number**, **Manufacturing Date**, **Expiry Date**, and **Certificate of Analysis (COA) / SDS verification**.
3. **Automated Directed Hazmat Putaway**:
   - Engine queries available bins in `/WH1/CHEM` matching `hazard_class`.
   - Recommends optimal bunded slot (e.g., `WH1-CHEM-BAY01-BUND-L1`).
4. **Execution & Inventory Posting**:
   - Operator places pallet/drum in assigned slot and scans bin barcode to confirm.
   - Creates `StockQuant` & `StockMove` records.
   - Automatically updates `PurchaseOrderLines.received_quantity` and sets `PurchaseOrders.status = 'received'` once all lines complete.
   - Posts journal entry to General Ledger: Debit *Chemical Inventory (1-1320)*, Credit *Accounts Payable (2-1000)*.

---

## 5. EXECUTION ROADMAP & SPRINT PHASING

| Sprint | Timeline | Module / Focus Area | Deliverables & Milestones |
| :--- | :--- | :--- | :--- |
| **Sprint 10** | Weeks 19 - 20 | **PO Receiving & Multi-WH Core** | • Link `PurchaseOrders` to `StockPickings` and `Locations`.<br>• `PurchaseOrderReceivingScreen` in Flutter.<br>• Destination warehouse selection (`/WH1`, `/WH2`). |
| **Sprint 11** | Weeks 21 - 22 | **Hazmat & Chemical Safety Matrix** | • Chemical metadata fields (`hazard_class`, `un_number`, `sds_url`).<br>• Chemical incompatibility putaway engine rules (`Prochloraz` & `Chlorine`).<br>• Bunded rack bay verification. |
| **Sprint 12** | Weeks 23 - 24 | **Inter-Warehouse Transit & Pharma/Clinic GSP** | • Virtual in-transit location `/TRANSIT/TRUCK-XX`.<br>• Clinic & Hospital location tree with bedside dispensing verification.<br>• 4-Eyes dual sign-off for controlled toxic agrochemicals & pharmaceuticals. |

---
