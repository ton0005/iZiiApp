import 'package:drift/drift.dart';

// ── 1. PRODUCTS ─────────────────────────────────────────────────────────────
class Products extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get sku => text().unique()();
  TextColumn get name => text()();
  RealColumn get price => real()();
  RealColumn get cost => real()();
  TextColumn get type => text()
      .withDefault(const Constant('product'))(); // product, service, consumable, medicine
  TextColumn get barcode =>
      text().nullable()(); // Unique handled at app level / GS1
  TextColumn get customFields => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 2. PRODUCT UOMS (Đơn vị tính đa cấp & Quy đổi) ───────────────────────────
class ProductUoms extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get productId => text()(); // References Products.id
  TextColumn get name => text()(); // e.g. kg, punnet, box, layer, pallet, vial
  TextColumn get uomType => text()
      .withDefault(const Constant('reference'))(); // reference, smaller, bigger
  RealColumn get ratioToBase => real().withDefault(const Constant(1.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 3. PRODUCT PACKAGINGS (Quy cách đóng gói hình học) ──────────────────────
class ProductPackagings extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get productId => text()(); // References Products.id
  TextColumn get name => text()(); // e.g. "Box 400x300", "Pallet AS 4068"
  RealColumn get qtyPerPackage => real().withDefault(const Constant(1.0))();
  TextColumn get uomId => text()(); // References ProductUoms.id
  RealColumn get lengthMm => real().nullable()();
  RealColumn get widthMm => real().nullable()();
  RealColumn get heightMm => real().nullable()();
  RealColumn get tareWeightKg => real().nullable().withDefault(const Constant(0.0))();
  TextColumn get barcode => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 4. STOCK LOTS (Quản lý Lô & Hạn sử dụng - FEFO Engine) ───────────────────
class StockLots extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get lotNumber => text()(); // e.g. 'LOT-20261005-R33-CUP'
  TextColumn get productId => text()(); // References Products.id
  DateTimeColumn get productionDate => dateTime().nullable()();
  DateTimeColumn get bestBeforeDate => dateTime().nullable()();
  DateTimeColumn get expiryDate => dateTime()();
  TextColumn get status => text()
      .withDefault(const Constant('quarantine'))(); // quarantine, approved, blocked, expired
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 5. STOCK LPNS (Biển số Pallet / Thùng LPN) ──────────────────────────────
class StockLpns extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get lpnCode => text().unique()(); // e.g. 'LPN-2026-M1-001248'
  TextColumn get locationId => text()(); // References Locations.id
  TextColumn get status => text()
      .withDefault(const Constant('staged'))(); // staged, stored, in_transit, shipped, empty
  RealColumn get grossWeightKg => real().nullable().withDefault(const Constant(0.0))();
  RealColumn get tareWeightKg => real().nullable().withDefault(const Constant(0.0))();
  RealColumn get netWeightKg => real().nullable().withDefault(const Constant(0.0))();
  TextColumn get packagingId => text().nullable()(); // References ProductPackagings.id
  TextColumn get customFields => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 6. STOCK LPN CONTENTS ───────────────────────────────────────────────────
class StockLpnContents extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get lpnId => text()(); // References StockLpns.id
  TextColumn get productId => text()(); // References Products.id
  TextColumn get lotId => text().nullable()(); // References StockLots.id
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  TextColumn get uomId => text()(); // References ProductUoms.id
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 7. STOCK QUANTS (Tồn kho định vị chi tiết) ──────────────────────────────
class StockQuants extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get productId => text()(); // References Products.id
  TextColumn get locationId => text()(); // References Locations.id
  TextColumn get lotId => text().nullable()(); // References StockLots.id
  TextColumn get lpnId => text().nullable()(); // References StockLpns.id
  RealColumn get quantity => real()();
  RealColumn get reservedQty => real().withDefault(const Constant(0.0))();
  RealColumn get availableQty => real().withDefault(const Constant(0.0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 8. STOCK PICKINGS (Phiếu Nhập/Xuất/Chuyển kho) ───────────────────────────
class StockPickings extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get code => text().unique()(); // e.g. 'IN-2026-0001'
  TextColumn get pickingType => text()(); // incoming_supplier, incoming_harvest, internal_transfer, outbound_sales, scrap
  TextColumn get originDocument => text().nullable()(); // PO-xxx, SO-xxx, HARVEST-xxx
  TextColumn get sourceLocationId => text().nullable()(); // References Locations.id
  TextColumn get destLocationId => text().nullable()(); // References Locations.id
  DateTimeColumn get scheduledDate => dateTime().nullable()();
  DateTimeColumn get completedDate => dateTime().nullable()();
  TextColumn get status => text()
      .withDefault(const Constant('draft'))(); // draft, waiting, confirmed, assigned, done, cancelled
  TextColumn get waveId => text().nullable()();
  TextColumn get priority => text().withDefault(const Constant('normal'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 9. STOCK PICKING LINES ──────────────────────────────────────────────────
class StockPickingLines extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get pickingId => text()(); // References StockPickings.id
  TextColumn get productId => text()(); // References Products.id
  TextColumn get lotId => text().nullable()(); // References StockLots.id
  TextColumn get lpnId => text().nullable()(); // References StockLpns.id
  TextColumn get sourceLocationId => text()(); // References Locations.id
  TextColumn get destLocationId => text()(); // References Locations.id
  RealColumn get demandQty => real().withDefault(const Constant(0.0))();
  RealColumn get reservedQty => real().withDefault(const Constant(0.0))();
  RealColumn get doneQty => real().withDefault(const Constant(0.0))();
  TextColumn get uomId => text()(); // References ProductUoms.id
  TextColumn get status => text()
      .withDefault(const Constant('draft'))(); // draft, reserved, done, cancelled
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 10. STOCK MOVES ─────────────────────────────────────────────────────────
class StockMoves extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get pickingId => text().nullable()(); // References StockPickings.id
  TextColumn get pickingLineId => text().nullable()(); // References StockPickingLines.id
  TextColumn get productId => text()(); // References Products.id
  TextColumn get lotId => text().nullable()(); // References StockLots.id
  TextColumn get lpnId => text().nullable()(); // References StockLpns.id
  TextColumn get sourceLocationId => text()(); // References Locations.id
  TextColumn get destLocationId => text()(); // References Locations.id
  RealColumn get quantity => real()();
  TextColumn get status => text()
      .withDefault(const Constant('draft'))(); // draft, done, cancelled
  TextColumn get transportType => text()
      .withDefault(const Constant('forklift'))(); // forklift, agv, conveyor, manual
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 11. PHARMA SERIAL NUMBERS (Serialization chống giả) ─────────────────────
class StockSerialNumbers extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get productId => text()(); // References Products.id
  TextColumn get lotId => text()(); // References StockLots.id
  TextColumn get serialNumber => text().unique()(); // GS1 Serial number
  TextColumn get locationId => text()(); // References Locations.id
  TextColumn get status => text()
      .withDefault(const Constant('available'))(); // available, reserved, dispensed, destroyed, recalled
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 12. PHARMA CONTROLLED APPROVALS (Ký duyệt kép thuốc gây nghiện) ─────────
class PharmaControlledApprovals extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get pickingLineId => text()(); // References StockPickingLines.id
  TextColumn get productId => text()(); // References Products.id
  TextColumn get authorizedBy1 => text()(); // Pharmacist User ID
  TextColumn get signature1 => text()();
  DateTimeColumn get timestamp1 => dateTime()();
  TextColumn get authorizedBy2 => text()(); // Physician User ID
  TextColumn get signature2 => text()();
  DateTimeColumn get timestamp2 => dateTime()();
  TextColumn get reasonNotes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── 13. PHARMA DISPENSING LOGS (Cấp phát thuốc đầu giường) ───────────────────
class PharmaDispensingLogs extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get prescriptionId => text()();
  TextColumn get patientId => text()();
  TextColumn get patientBarcode => text()(); // Wristband barcode
  TextColumn get productId => text()(); // References Products.id
  TextColumn get lotId => text()(); // References StockLots.id
  TextColumn get serialNumberId => text().nullable()(); // References StockSerialNumbers.id
  RealColumn get dispensedQty => real().withDefault(const Constant(1.0))();
  TextColumn get dispensedBy => text()(); // Nurse User ID
  DateTimeColumn get verifiedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
