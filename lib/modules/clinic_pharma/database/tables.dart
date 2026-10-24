import 'package:drift/drift.dart';

class Doctors extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text()();
  TextColumn get specialty => text().withDefault(const Constant(''))();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  // Đơn thuốc quốc gia (QĐ 808): mã liên thông bác sĩ = '01' + số CCHN bỏ dấu '/'.
  TextColumn get soCchn => text().nullable()();
  TextColumn get maLienThongDtqg => text().nullable()();
  BoolColumn get duocKeDon => boolean().withDefault(const Constant(true))();
  TextColumn get dtqgStatus => text().withDefault(const Constant('pending'))(); // pending, active, paused, revoked
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get customFields => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Patients extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get fullName => text()();
  DateTimeColumn get dob => dateTime().nullable()();
  TextColumn get gender => text().nullable()(); // male, female, other
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get idNumber => text().nullable()(); // CMND/CCCD/BHYT
  TextColumn get maDinhDanhYte => text().nullable()();
  TextColumn get soCccd => text().nullable()();
  TextColumn get maTheBhyt => text().nullable()();
  TextColumn get guardianName => text().nullable()();
  TextColumn get guardianPhone => text().nullable()();
  TextColumn get guardianAddress => text().nullable()();
  TextColumn get customFields => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Appointments extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get patientId => text()();
  TextColumn get doctorId => text().nullable()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get reason => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('scheduled'))(); // scheduled, checked_in, completed, cancelled, no_show
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MedicalVisits extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get patientId => text()();
  TextColumn get doctorId => text().nullable()();
  TextColumn get appointmentId => text().nullable()();
  DateTimeColumn get visitDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get chiefComplaint => text().nullable()();
  TextColumn get diagnosis => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))(); // open, completed
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Prescriptions extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get visitId => text()();
  TextColumn get patientId => text()();
  TextColumn get doctorId => text().nullable()();
  DateTimeColumn get prescriptionDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, dispensed, cancelled
  TextColumn get notes => text().nullable()();
  // Đơn thuốc quốc gia (QĐ 808)
  TextColumn get maDonThuoc => text().nullable()(); // xxxxxyyyyyyy-c (14 ký tự)
  TextColumn get loaiDon => text().withDefault(const Constant('c'))();
  TextColumn get chanDoanJson => text().withDefault(const Constant('[]'))(); // [{ma_benh, ten_benh, ket_luan}]
  RealColumn get canNang => real().nullable()();
  IntColumn get hinhThucDieuTri => integer().nullable()();
  TextColumn get nguoiGiamHo => text().nullable()();
  TextColumn get loiDan => text().nullable()();
  IntColumn get ngayTaiKham => integer().nullable()(); // số ngày kể từ ngày kê
  TextColumn get dtqgStatus => text().withDefault(const Constant('draft'))(); // draft, queued, sent, rejected
  DateTimeColumn get dtqgSentAt => dateTime().nullable()();
  TextColumn get dtqgLastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class PrescriptionItems extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get prescriptionId => text()();
  TextColumn get productId => text()(); // references supply_chain Products.id
  TextColumn get medicineName => text()(); // denormalized snapshot
  TextColumn get dosageInstructions => text().nullable()();
  TextColumn get maThuocCucQldd => text().nullable()(); // ma_thuoc (≤ 20)
  TextColumn get bietDuoc => text().nullable()(); // biet_duoc (≤ 500)
  TextColumn get donViTinh => text().nullable()();
  RealColumn get soLuongBan => real().nullable()(); // POS: số lượng đã bán
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  RealColumn get unitPrice => real().withDefault(const Constant(0.0))();
  RealColumn get totalPrice => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Thông tin cơ sở KCB / nhà thuốc (một dòng, id = 'default'). In lên đơn và
/// dùng làm 5 ký tự đầu của mã đơn thuốc. Mật khẩu liên thông KHÔNG lưu ở đây.
class ClinicFacility extends Table {
  TextColumn get id => text().withDefault(const Constant('default'))();
  TextColumn get maCskcb => text().withDefault(const Constant(''))(); // 5 ký tự
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get maLienThongDtqg => text().nullable()();
  // Mã định danh cơ sở cung ứng thuốc (tài khoản liên thông Dược quốc gia) — vai trò POS.
  TextColumn get maDinhDanhCungUng => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
