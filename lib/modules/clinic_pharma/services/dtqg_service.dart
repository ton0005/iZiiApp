import 'package:dio/dio.dart';

import '../../../core/settings/settings_service.dart';

/// Kết quả gọi API Đơn thuốc quốc gia của iZiiServer (`/api/v1/dtqg/*`).
/// App không bao giờ giữ mật khẩu liên thông, token hay app-key: server giữ
/// và gọi donthuocquocgia.vn thay mặt (plan 03, mục 5).
class DtqgException implements Exception {
  final String message;
  final int? status;
  const DtqgException(this.message, [this.status]);
  @override
  String toString() => message;
}

class PosLine {
  final String maThuoc; // mã thuốc đã kê (key để bán)
  final String bietDuoc;
  final String tenThuoc;
  final String donViTinh;
  final String cachDung;
  final double soLuong;
  final double daBan;
  final double conLai;

  const PosLine({
    required this.maThuoc,
    required this.bietDuoc,
    required this.tenThuoc,
    required this.donViTinh,
    required this.cachDung,
    required this.soLuong,
    required this.daBan,
    required this.conLai,
  });

  factory PosLine.fromJson(Map<String, dynamic> j) => PosLine(
        maThuoc: (j['ma_thuoc'] ?? '').toString(),
        bietDuoc: (j['biet_duoc'] ?? '').toString(),
        tenThuoc: (j['ten_thuoc'] ?? '').toString(),
        donViTinh: (j['don_vi_tinh'] ?? '').toString(),
        cachDung: (j['cach_dung'] ?? '').toString(),
        soLuong: (j['so_luong'] as num?)?.toDouble() ?? 0,
        daBan: (j['da_ban'] as num?)?.toDouble() ?? 0,
        conLai: (j['con_lai'] as num?)?.toDouble() ?? 0,
      );
}

class PosPrescription {
  final String maDonThuoc;
  final String hoTen;
  final String ngaySinh;
  final String diaChi;
  final String tenBacSi;
  final String tenCoSo;
  final String ngayGioKeDon;
  final String? luuY;
  final String? loiDan;
  final List<Map<String, dynamic>> chanDoan;
  final List<PosLine> lines;
  final bool hetHan;
  final bool daBanHet;
  final bool coTheBan;
  final String? hetHanLuc;

  const PosPrescription({
    required this.maDonThuoc,
    required this.hoTen,
    required this.ngaySinh,
    required this.diaChi,
    required this.tenBacSi,
    required this.tenCoSo,
    required this.ngayGioKeDon,
    required this.chanDoan,
    required this.lines,
    required this.hetHan,
    required this.daBanHet,
    required this.coTheBan,
    this.luuY,
    this.loiDan,
    this.hetHanLuc,
  });

  factory PosPrescription.fromLookup(Map<String, dynamic> j) {
    final rx = Map<String, dynamic>.from(j['prescription'] as Map);
    return PosPrescription(
      maDonThuoc: (rx['ma_don_thuoc'] ?? '').toString(),
      hoTen: (rx['ho_ten_benh_nhan'] ?? '').toString(),
      ngaySinh: (rx['ngay_sinh_benh_nhan'] ?? '').toString(),
      diaChi: (rx['dia_chi'] ?? '').toString(),
      tenBacSi: (rx['ten_bac_si'] ?? '').toString(),
      tenCoSo: (rx['ten_co_so_kham_chua_benh'] ?? '').toString(),
      ngayGioKeDon: (rx['ngay_gio_ke_don'] ?? '').toString(),
      luuY: rx['luu_y'] as String?,
      loiDan: rx['loi_dan'] as String?,
      chanDoan: ((rx['chan_doan'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      lines: ((rx['thong_tin_don_thuoc'] as List?) ?? const [])
          .map((e) => PosLine.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      hetHan: j['het_han'] == true,
      daBanHet: j['da_ban_het'] == true,
      coTheBan: j['co_the_ban'] == true,
      hetHanLuc: j['het_han_luc'] as String?,
    );
  }
}

class SellResult {
  /// sent | retry | rejected | blocked | lookup_failed
  final String result;
  final List<String> errors;
  const SellResult(this.result, this.errors);
  bool get recorded => result == 'sent' || result == 'retry';
}

/// Một đơn thuốc cùng trạng thái liên thông (server là nguồn sự thật).
class DtqgRxStatus {
  final String id;
  final String? maDonThuoc;
  final String status; // draft | queued | sent | rejected
  final String? lastError;
  final String? sentAt;
  final String? prescriptionDate;
  final String patientName;
  final String doctorName;
  final int itemCount;

  const DtqgRxStatus({
    required this.id,
    required this.status,
    required this.patientName,
    required this.doctorName,
    required this.itemCount,
    this.maDonThuoc,
    this.lastError,
    this.sentAt,
    this.prescriptionDate,
  });

  factory DtqgRxStatus.fromJson(Map<String, dynamic> j) => DtqgRxStatus(
        id: j['id'].toString(),
        maDonThuoc: j['ma_don_thuoc'] as String?,
        status: (j['dtqg_status'] ?? 'draft').toString(),
        lastError: j['dtqg_last_error'] as String?,
        sentAt: j['dtqg_sent_at'] as String?,
        prescriptionDate: j['prescription_date'] as String?,
        patientName: (j['patient_name'] ?? '').toString(),
        doctorName: (j['doctor_name'] ?? '').toString(),
        itemCount: (j['item_count'] as num?)?.toInt() ?? 0,
      );
}

class DtqgService {
  static final DtqgService _instance = DtqgService._internal();
  factory DtqgService() => _instance;
  DtqgService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 40),
    validateStatus: (_) => true, // tự đọc lỗi của server
  ));
  final SettingsService _settings = SettingsService();

  Future<String> _baseUrl() async =>
      (await _settings.getSyncServerUrl()).replaceAll(RegExp(r'/+$'), '');

  Future<Map<String, String>> _headers() async {
    final url = await _baseUrl();
    final deviceToken = await _settings.getDeviceToken(url);
    final adminToken = await _settings.getSyncToken();
    return {
      if (deviceToken != null && deviceToken.isNotEmpty) 'X-iZii-Device-Token': deviceToken,
      if (adminToken.isNotEmpty) 'X-iZii-Admin-Token': adminToken,
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final Response resp;
    try {
      resp = await _dio.post('${await _baseUrl()}/api/v1/dtqg$path',
          data: body, options: Options(headers: await _headers()));
    } on DioException catch (e) {
      throw DtqgException('Không kết nối được máy chủ iZii: ${e.message ?? e.type.name}');
    }
    final data = resp.data;
    if (resp.statusCode == 401) {
      throw const DtqgException('Thiết bị chưa được cấp quyền (cần đăng ký thiết bị hoặc token quản trị).', 401);
    }
    if (resp.statusCode == 503) {
      final d = data is Map ? data['detail'] : null;
      throw DtqgException(d?.toString() ?? 'Liên thông Đơn thuốc quốc gia đang tắt trên máy chủ.', 503);
    }
    if (resp.statusCode != null && resp.statusCode! >= 400 && data is! Map) {
      throw DtqgException('Lỗi máy chủ (${resp.statusCode})', resp.statusCode);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  List<String> _errors(Map<String, dynamic> j) =>
      ((j['errors'] as List?) ?? const []).map((e) => e.toString()).toList();

  /// Tra đơn theo mã. Ném [DtqgException] kèm lỗi nguyên văn của hệ thống quốc gia.
  Future<PosPrescription> lookup(String maDonThuoc) async {
    final j = await _post('/pos/lookup', {'ma_don_thuoc': maDonThuoc.trim().toLowerCase()});
    if (j['ok'] != true) {
      final errs = _errors(j);
      throw DtqgException(errs.isEmpty ? 'Không tra được đơn thuốc' : errs.join('\n'),
          (j['status'] as num?)?.toInt());
    }
    return PosPrescription.fromLookup(j);
  }

  /// [lines]: `{ma_thuoc_da_ke_don, so_luong_ban, [ma_thuoc, biet_duoc, ten_thuoc, don_vi_tinh, cach_dung]}`.
  /// Chỉ khi đã GHI NHẬN (sent/retry) mới được trừ kho cục bộ.
  Future<SellResult> sell({
    required String maDonThuoc,
    required String maHoaDon,
    required List<Map<String, dynamic>> lines,
  }) async {
    final j = await _post('/pos/sell', {
      'ma_don_thuoc': maDonThuoc,
      'ma_hoa_don': maHoaDon,
      'lines': lines,
    });
    return SellResult((j['result'] ?? 'rejected').toString(), _errors(j));
  }

  Future<List<DtqgRxStatus>> listPrescriptions({String? status, int limit = 200}) async {
    final Response resp;
    try {
      resp = await _dio.get('${await _baseUrl()}/api/v1/dtqg/prescriptions',
          queryParameters: {if (status != null) 'status': status, 'limit': limit},
          options: Options(headers: await _headers()));
    } on DioException catch (e) {
      throw DtqgException('Không kết nối được máy chủ iZii: ${e.message ?? e.type.name}');
    }
    if (resp.statusCode == 401) {
      throw const DtqgException('Thiết bị chưa được cấp quyền (cần đăng ký thiết bị hoặc token quản trị).', 401);
    }
    if (resp.statusCode != 200 || resp.data is! Map) {
      throw DtqgException('Lỗi máy chủ (${resp.statusCode})', resp.statusCode);
    }
    return ((resp.data['prescriptions'] as List?) ?? const [])
        .map((e) => DtqgRxStatus.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Gửi ngay một đơn đã kê (không đợi vòng nền).
  Future<SellResult> sendPrescription(String prescriptionId) async {
    final j = await _post('/prescriptions/$prescriptionId/send', {});
    return SellResult((j['result'] ?? 'rejected').toString(), _errors(j));
  }
}
