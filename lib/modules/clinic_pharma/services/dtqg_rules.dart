import 'dart:math';

/// Quy tắc Đơn thuốc quốc gia (QĐ 808/QĐ-BYT + Hướng dẫn sử dụng).
/// Thuần Dart, không phụ thuộc DB/UI để test được.
///
/// Phạm vi hiện tại: chỉ đơn loại `c` (đơn thuốc thông thường).
class DtqgRules {
  DtqgRules._();

  static const _alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';

  /// `xxxxxyyyyyyy-c`: 5 ký tự mã CSKCB + 7 ký tự `[0-9a-z]` + `-` + loại đơn.
  static String generateMaDonThuoc(String maCskcb, {String loai = 'c', Random? random}) {
    final cs = maCskcb.trim().toLowerCase();
    if (cs.length != 5) {
      throw ArgumentError('Mã CSKCB phải đủ 5 ký tự (hiện: "$maCskcb")');
    }
    final rnd = random ?? Random.secure();
    final tail = List.generate(7, (_) => _alphabet[rnd.nextInt(_alphabet.length)]).join();
    return '$cs$tail-${loai.toLowerCase()}';
  }

  static final _maDonRe = RegExp(r'^[0-9a-z]{12}-[chny]$');
  static bool isValidMaDonThuoc(String? s) => s != null && _maDonRe.hasMatch(s);

  /// Giới tính nội bộ → mã của hệ thống: 1 chưa có thông tin, 2 Nam, 3 Nữ.
  static int mapGender(String? g) {
    switch (g) {
      case 'male':
        return 2;
      case 'female':
        return 3;
      default:
        return 1;
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// `d/m/Y`
  static String formatDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

  /// `Y-m-d H:i:s` (tài liệu ghi `H:m:s` — xem mục 9 của plan).
  static String formatDateTime(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

  /// Mã liên thông bác sĩ = `01` + số CCHN bỏ dấu `/` (FAQ 1.17).
  static String maLienThongBacSi(String soCchn) =>
      '01${soCchn.trim().replaceAll('/', '')}';

  static int? ageInMonths(DateTime? dob, DateTime now) {
    if (dob == null) return null;
    var m = (now.year - dob.year) * 12 + now.month - dob.month;
    if (now.day < dob.day) m--;
    return m < 0 ? 0 : m;
  }

  static bool isUnder72Months(DateTime? dob, DateTime now) {
    final m = ageInMonths(dob, now);
    return m != null && m < 72;
  }

  /// Trả danh sách lỗi (rỗng = hợp lệ) theo mục 6 của plan.
  static List<String> validate({
    required Map<String, dynamic> patient,
    required Map<String, dynamic>? doctor,
    required List<Map<String, dynamic>> diagnoses,
    required List<Map<String, dynamic>> items,
    required double? canNang,
    required String? nguoiGiamHo,
    required int? hinhThucDieuTri,
    String loai = 'c',
    DateTime? now,
  }) {
    final errors = <String>[];
    final t = now ?? DateTime.now();
    String s(dynamic v) => (v as String? ?? '').trim();

    if (s(patient['full_name']).isEmpty) errors.add('Thiếu họ tên bệnh nhân');
    final dob = DateTime.tryParse(s(patient['dob']));
    if (dob == null) errors.add('Thiếu ngày sinh bệnh nhân');
    if (s(patient['address']).isEmpty) errors.add('Thiếu địa chỉ bệnh nhân');
    final phone = s(patient['phone']);
    if (phone.isEmpty) {
      errors.add('Thiếu số điện thoại bệnh nhân/người giám hộ');
    } else if (!RegExp(r'^\d{1,12}$').hasMatch(phone)) {
      errors.add('Số điện thoại chỉ gồm chữ số, tối đa 12');
    }
    final cccd = s(patient['so_cccd']);
    if (cccd.isNotEmpty && !RegExp(r'^\d{12}$').hasMatch(cccd)) {
      errors.add('Mã định danh công dân phải đủ 12 chữ số');
    }
    if (s(patient['ma_dinh_danh_y_te']).length > 10) {
      errors.add('Mã định danh y tế tối đa 10 ký tự');
    }
    if (s(patient['ma_the_bhyt']).length > 15) {
      errors.add('Mã thẻ BHYT tối đa 15 ký tự');
    }

    if (isUnder72Months(dob, t)) {
      if (canNang == null || canNang <= 0) {
        errors.add('Trẻ dưới 72 tháng tuổi: bắt buộc nhập cân nặng');
      }
      if ((nguoiGiamHo ?? '').trim().isEmpty) {
        errors.add('Trẻ dưới 72 tháng tuổi: bắt buộc nhập thông tin người giám hộ');
      }
    }
    if ((nguoiGiamHo ?? '').length > 500) {
      errors.add('Thông tin người giám hộ tối đa 500 ký tự');
    }

    if (diagnoses.isEmpty) {
      errors.add('Cần ít nhất một chẩn đoán');
    } else if (diagnoses.any((d) => s(d['ma_benh']).isEmpty || s(d['ten_benh']).isEmpty)) {
      errors.add('Mỗi chẩn đoán cần mã bệnh và tên bệnh');
    }

    if (loai == 'c' && hinhThucDieuTri == null) {
      errors.add('Đơn thông thường cần hình thức điều trị');
    }

    if (doctor == null) {
      errors.add('Chưa chọn bác sĩ kê đơn');
    } else {
      if (doctor['duoc_ke_don'] == false) errors.add('Bác sĩ không được phân công kê đơn');
      if (doctor['dtqg_status'] != 'active') {
        errors.add('Bác sĩ chưa có mã liên thông được duyệt (trạng thái: ${doctor['dtqg_status']})');
      }
    }

    if (items.isEmpty) errors.add('Đơn thuốc chưa có thuốc nào');
    for (final it in items) {
      final name = s(it['medicine_name']);
      final label = name.isEmpty ? 'Dòng thuốc' : '"$name"';
      final ma = s(it['ma_thuoc_cuc_qldd']);
      if (ma.isEmpty) {
        errors.add('$label: thiếu mã thuốc (Cục Quản lý Dược)');
      } else if (ma.length > 20) {
        errors.add('$label: mã thuốc tối đa 20 ký tự');
      }
      if (s(it['biet_duoc']).isEmpty) errors.add('$label: thiếu biệt dược/hoạt chất');
      if (s(it['don_vi_tinh']).isEmpty) errors.add('$label: thiếu đơn vị tính');
      if (((it['quantity'] as num?) ?? 0) <= 0) errors.add('$label: số lượng phải lớn hơn 0');
      final cach = s(it['dosage_instructions']);
      if (cach.isEmpty) {
        errors.add('$label: thiếu cách dùng');
      } else if (cach.length > 500) {
        errors.add('$label: cách dùng tối đa 500 ký tự');
      }
    }
    return errors;
  }

  /// Dựng body `gui-don-thuoc`. Tên khóa nằm ở đây (một chỗ) vì tài liệu còn
  /// mâu thuẫn (plan mục 9): đổi [chanDoanKeys] / [bhytKey] khi xác nhận xong.
  static Map<String, dynamic> buildGuiDonPayload({
    required String maDonThuoc,
    required Map<String, dynamic> patient,
    required List<Map<String, dynamic>> diagnoses,
    required List<Map<String, dynamic>> items,
    required DateTime keDonAt,
    double? canNang,
    String? nguoiGiamHo,
    int? hinhThucDieuTri,
    String? luuY,
    String? loiDan,
    int? ngayTaiKham,
    String loai = 'c',
    ({String ma, String ten}) chanDoanKeys = (ma: 'ma_benh', ten: 'ten_benh'),
    String bhytKey = 'ma_so_bao_hiem_y_te',
  }) {
    String? nz(dynamic v) {
      final t = (v as String? ?? '').trim();
      return t.isEmpty ? null : t;
    }

    final dob = DateTime.tryParse(patient['dob'] as String? ?? '');
    return {
      'loai_don_thuoc': loai,
      'ma_don_thuoc': maDonThuoc,
      'ho_ten_benh_nhan': (patient['full_name'] as String).trim(),
      'ngay_sinh_benh_nhan': dob == null ? null : formatDate(dob),
      'ma_dinh_danh_y_te': nz(patient['ma_dinh_danh_y_te']),
      'ma_dinh_danh_cong_dan': nz(patient['so_cccd']),
      'can_nang': canNang,
      'gioi_tinh': mapGender(patient['gender'] as String?),
      bhytKey: nz(patient['ma_the_bhyt']),
      'thong_tin_nguoi_giam_ho': nz(nguoiGiamHo),
      'dia_chi': (patient['address'] as String? ?? '').trim(),
      'chan_doan': [
        for (final d in diagnoses)
          {
            chanDoanKeys.ma: d['ma_benh'],
            chanDoanKeys.ten: d['ten_benh'],
            'ket_luan': d['ket_luan'] ?? '',
          }
      ],
      'luu_y': nz(luuY),
      'hinh_thuc_dieu_tri': hinhThucDieuTri,
      'thong_tin_don_thuoc': [
        for (final it in items)
          {
            'ma_thuoc': it['ma_thuoc_cuc_qldd'],
            'biet_duoc': it['biet_duoc'],
            'ten_thuoc': it['medicine_name'],
            'don_vi_tinh': it['don_vi_tinh'],
            'so_luong': it['quantity'],
            'cach_dung': it['dosage_instructions'],
          }
      ],
      'loi_dan': nz(loiDan),
      'so_dien_thoai_nguoi_kham_benh': nz(patient['phone']),
      'ngay_tai_kham': ngayTaiKham,
      'ngay_gio_ke_don': formatDateTime(keDonAt),
      'signature': null, // chưa triển khai (FAQ 1.6, 1.22)
    };
  }
}
