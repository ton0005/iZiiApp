import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../repository.dart';

/// 5 nhóm phân loại sự cố / hành động theo quy trình nuôi trồng nấm
enum WindowIssueCategory {
  disease, // 🦠 Dịch bệnh / Bệnh hại (Trichoderma, Wet Bubble, Dry Bubble, Cobweb, Sciarid fly...)
  safety, // ⚠️ An toàn lao động (Thành luống lỏng, trụ nhôm cong, nồng độ CO2 cao, sàn trơn...)
  qa, // 🔍 Chất lượng / QA (Casing khô, quá dày, nấm nhỏ cuống dài, đốm bẩn...)
  working, // ⏱️ Thao tác / Công việc (Hái không đều, sót chân nấm, dập nụ non, quá giờ...)
  maintenance, // 🛠️ Bảo trì / Kỹ thuật (Béc tưới rò rỉ, cảm biến hỏng, kẹt máng xe, quạt lệch...)
}

extension WindowIssueCategoryExt on WindowIssueCategory {
  String get id => name;

  String get displayName {
    switch (this) {
      case WindowIssueCategory.disease:
        return 'Disease';
      case WindowIssueCategory.safety:
        return 'Safety';
      case WindowIssueCategory.qa:
        return 'QA & Quality';
      case WindowIssueCategory.working:
        return 'Operation';
      case WindowIssueCategory.maintenance:
        return 'Maintenance';
    }
  }

  String get iconEmoji {
    switch (this) {
      case WindowIssueCategory.disease:
        return '🦠';
      case WindowIssueCategory.safety:
        return '⚠️';
      case WindowIssueCategory.qa:
        return '🔍';
      case WindowIssueCategory.working:
        return '⏱️';
      case WindowIssueCategory.maintenance:
        return '🛠️';
    }
  }

  List<String> get presets {
    switch (this) {
      case WindowIssueCategory.disease:
        return [
          'Trichoderma (Green Mould)',
          'Wet Bubble (Mycogone)',
          'Dry Bubble (Lecanicillium)',
          'Cobweb (Cladobotryum)',
          'Sciarid / Phorid fly',
          'Bacterial Blotch',
        ];
      case WindowIssueCategory.safety:
        return [
          'Loose sideboard / hazard',
          'Bent aluminum post / rail',
          'High CO2 / Gas spike',
          'Slippery aisle floor with water pooling',
          'High level fall risk (Level 5-6)',
          'Damaged / flickering aisle light',
        ];
      case WindowIssueCategory.qa:
        return [
          'Dry casing soil / low moisture',
          'Over-pinning (thinning required)',
          'Small cap / long stem (low O2)',
          'Soil / peat debris on cap',
          'Cap cracking / scaling',
          'Uneven pin distribution',
        ];
      case WindowIssueCategory.working:
        return [
          'Leftover stalks after picking',
          'Uneven picking size / off-spec',
          'Damaged next-flush pins',
          'Exceeded standard cycle time',
          'Incorrect punnet / crate packing',
        ];
      case WindowIssueCategory.maintenance:
        return [
          'Leaking / clogged spray nozzle',
          'Temperature / RH sensor fault',
          'Picking lorry track jammed',
          'Damper valve stuck closed',
          'Cooling water line leak',
        ];
    }
  }
}

/// Báo cáo sự cố / hành động được tạo từ ô luống Window
class WindowIssueReport {
  final String id;
  final String roomName; // Ví dụ: "Room 33"
  final int rackIndex; // 0..3
  final int levelIndex; // 0..5
  final int windowIndex; // 0..8
  final String windowCode; // "R2-L3-W5"
  final WindowIssueCategory category;
  final String title;
  final String description;
  final String severity; // "low", "normal", "high", "critical"
  final String reporterName;
  final DateTime createdAt;
  final String status; // "open", "in_progress", "resolved"

  // Telemetry snapshot lúc ghi nhận
  final double temperature;
  final double humidity;
  final double co2;
  final double casingTemp;

  WindowIssueReport({
    required this.id,
    required this.roomName,
    required this.rackIndex,
    required this.levelIndex,
    required this.windowIndex,
    required this.windowCode,
    required this.category,
    required this.title,
    required this.description,
    required this.severity,
    required this.reporterName,
    required this.createdAt,
    this.status = 'open',
    required this.temperature,
    required this.humidity,
    required this.co2,
    required this.casingTemp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomName': roomName,
        'rackIndex': rackIndex,
        'levelIndex': levelIndex,
        'windowIndex': windowIndex,
        'windowCode': windowCode,
        'category': category.name,
        'title': title,
        'description': description,
        'severity': severity,
        'reporterName': reporterName,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
        'temperature': temperature,
        'humidity': humidity,
        'co2': co2,
        'casingTemp': casingTemp,
      };

  factory WindowIssueReport.fromJson(Map<String, dynamic> json) {
    return WindowIssueReport(
      id: json['id'] as String,
      roomName: json['roomName'] as String,
      rackIndex: json['rackIndex'] as int? ?? 0,
      levelIndex: json['levelIndex'] as int? ?? 0,
      windowIndex: json['windowIndex'] as int? ?? 0,
      windowCode: json['windowCode'] as String? ?? 'R1-L1-W1',
      category: WindowIssueCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => WindowIssueCategory.disease,
      ),
      title: json['title'] as String? ?? 'Window Issue',
      description: json['description'] as String? ?? '',
      severity: json['severity'] as String? ?? 'normal',
      reporterName: json['reporterName'] as String? ?? 'Staff',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'open',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 19.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 90.0,
      co2: (json['co2'] as num?)?.toDouble() ?? 1150.0,
      casingTemp: (json['casingTemp'] as num?)?.toDouble() ?? 19.5,
    );
  }

  WindowIssueReport copyWith({
    String? status,
    String? title,
    String? description,
    String? severity,
  }) {
    return WindowIssueReport(
      id: id,
      roomName: roomName,
      rackIndex: rackIndex,
      levelIndex: levelIndex,
      windowIndex: windowIndex,
      windowCode: windowCode,
      category: category,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      reporterName: reporterName,
      createdAt: createdAt,
      status: status ?? this.status,
      temperature: temperature,
      humidity: humidity,
      co2: co2,
      casingTemp: casingTemp,
    );
  }
}

/// Dịch vụ quản lý, lưu trữ và phát thông báo sự cố / hành động trên các ô Window
class WindowActionService {
  static final WindowActionService _instance = WindowActionService._internal();
  factory WindowActionService() => _instance;
  WindowActionService._internal();

  static const String _prefKey = 'izii_grow_room_window_issues_v1';
  final _issuesController =
      StreamController<List<WindowIssueReport>>.broadcast();

  Stream<List<WindowIssueReport>> get issuesStream => _issuesController.stream;

  List<WindowIssueReport> _cachedIssues = [];
  bool _isInitialized = false;

  /// Khởi tạo và nạp dữ liệu từ lưu trữ
  Future<List<WindowIssueReport>> getIssues({String? roomName}) async {
    if (!_isInitialized) {
      await _loadFromStorage();
      _isInitialized = true;
    }

    if (roomName != null && roomName.isNotEmpty) {
      return _cachedIssues.where((i) => i.roomName == roomName).toList();
    }
    return List.unmodifiable(_cachedIssues);
  }

  /// Lấy danh sách tất cả các sự cố đang mở (open hoặc in_progress)
  Future<List<WindowIssueReport>> getActiveIssues({String? roomName}) async {
    final all = await getIssues(roomName: roomName);
    return all.where((i) => i.status != 'resolved').toList();
  }

  /// Đếm tổng số sự cố đang mở
  Future<int> getActiveIssuesCount({String? roomName}) async {
    final active = await getActiveIssues(roomName: roomName);
    return active.length;
  }

  /// Nạp danh sách từ SharedPreferences (hoặc gieo mầm dữ liệu mẫu nếu trống)
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List list = jsonDecode(jsonStr);
        _cachedIssues =
            list.map((e) => WindowIssueReport.fromJson(e)).toList();
      } else {
        // Gieo mầm các sự cố mẫu thực tế để kiểm tra ngay
        _cachedIssues = _createSeedIssues();
        await _saveToStorage();
      }
    } catch (_) {
      _cachedIssues = _createSeedIssues();
    }
    _notify();
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_cachedIssues.map((e) => e.toJson()).toList());
      await prefs.setString(_prefKey, jsonStr);
    } catch (_) {}
    _notify();
  }

  void _notify() {
    _issuesController.add(List.unmodifiable(_cachedIssues));
  }

  /// Báo cáo sự cố mới cho một Window
  Future<WindowIssueReport> reportIssue({
    required String roomName,
    required int rackIndex,
    required int levelIndex,
    required int windowIndex,
    required WindowIssueCategory category,
    required String title,
    required String description,
    required String severity,
    required String reporterName,
    required double temperature,
    required double humidity,
    required double co2,
    required double casingTemp,
  }) async {
    if (!_isInitialized) {
      await _loadFromStorage();
      _isInitialized = true;
    }

    final windowCode =
        'R${rackIndex + 1}-L${levelIndex + 1}-W${windowIndex + 1}';
    final now = DateTime.now();
    final issueId =
        'ACT-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 100000}';

    final report = WindowIssueReport(
      id: issueId,
      roomName: roomName,
      rackIndex: rackIndex,
      levelIndex: levelIndex,
      windowIndex: windowIndex,
      windowCode: windowCode,
      category: category,
      title: title,
      description: description,
      severity: severity,
      reporterName: reporterName,
      createdAt: now,
      status: 'open',
      temperature: temperature,
      humidity: humidity,
      co2: co2,
      casingTemp: casingTemp,
    );

    _cachedIssues.insert(0, report);
    await _saveToStorage();

    // Nếu sự cố thuộc nhóm Maintenance, tự động đồng bộ tạo Maintenance Ticket trong DB
    if (category == WindowIssueCategory.maintenance) {
      try {
        await MushroomsRepository().createMaintenanceTicket(
          title: '[$windowCode] $title',
          plant: roomName.contains(RegExp(r'3[3-9]|[4-6][0-9]')) ? 'M2' : 'M1',
          room: roomName,
          assignee: 'Nam (Maintenance)',
          priority: severity == 'critical' ? 'high' : 'normal',
          notes: 'Vị trí: $windowCode\n$description\nBáo cáo bởi: $reporterName',
        );
      } catch (_) {}
    }

    return report;
  }

  /// Cập nhật trạng thái sự cố ("open", "in_progress", "resolved")
  Future<void> updateIssueStatus(String issueId, String newStatus) async {
    final idx = _cachedIssues.indexWhere((i) => i.id == issueId);
    if (idx != -1) {
      _cachedIssues[idx] = _cachedIssues[idx].copyWith(status: newStatus);
      await _saveToStorage();
    }
  }

  /// Xóa sự cố
  Future<void> deleteIssue(String issueId) async {
    _cachedIssues.removeWhere((i) => i.id == issueId);
    await _saveToStorage();
  }

  /// Lấy bản đồ các ô đang có sự cố chưa xử lý theo phòng
  Future<Map<String, WindowIssueReport>> getActiveIssuesMap(
      String roomName) async {
    final issues = await getIssues(roomName: roomName);
    final map = <String, WindowIssueReport>{};
    for (final i in issues) {
      if (i.status != 'resolved') {
        map[i.windowCode] = i;
      }
    }
    return map;
  }

  List<WindowIssueReport> _createSeedIssues() {
    final now = DateTime.now();
    return [
      WindowIssueReport(
        id: 'ACT-20260917-001',
        roomName: 'Room 33',
        rackIndex: 0,
        levelIndex: 1, // Level 2
        windowIndex: 3, // Window 4
        windowCode: 'R1-L2-W4',
        category: WindowIssueCategory.disease,
        title: 'Trichoderma (Green Mould) patch detected',
        description:
            'Green mould patch ~5cm spotted near the inner sideboard. Salt application and quarantine required to avoid spore dispersal.',
        severity: 'critical',
        reporterName: 'Vinh (Growing Lead)',
        createdAt: now.subtract(const Duration(hours: 3)),
        status: 'open',
        temperature: 18.6,
        humidity: 91.5,
        co2: 1180.0,
        casingTemp: 19.6,
      ),
      WindowIssueReport(
        id: 'ACT-20260917-002',
        roomName: 'Room 33',
        rackIndex: 1,
        levelIndex: 3, // Level 4
        windowIndex: 6, // Window 7
        windowCode: 'R2-L4-W7',
        category: WindowIssueCategory.maintenance,
        title: 'Misting spray nozzle leaking water',
        description:
            'Nozzle head constantly dripping and creating puddle on casing surface, high risk of pinhead rot.',
        severity: 'high',
        reporterName: 'Hai (Harvest Supervisor)',
        createdAt: now.subtract(const Duration(hours: 5)),
        status: 'in_progress',
        temperature: 19.3,
        humidity: 93.0,
        co2: 1140.0,
        casingTemp: 19.8,
      ),
      WindowIssueReport(
        id: 'ACT-20260917-003',
        roomName: 'Room 33',
        rackIndex: 2,
        levelIndex: 4, // Level 5
        windowIndex: 1, // Window 2
        windowCode: 'R3-L5-W2',
        category: WindowIssueCategory.safety,
        title: 'Loose sideboard bolt hazard',
        description:
            'Level 5 aluminum sideboard misaligned, risk of falling down to lower levels when picking lorry passes.',
        severity: 'high',
        reporterName: 'Mike (Site Manager)',
        createdAt: now.subtract(const Duration(hours: 7)),
        status: 'open',
        temperature: 19.8,
        humidity: 89.2,
        co2: 1220.0,
        casingTemp: 20.1,
      ),
      WindowIssueReport(
        id: 'ACT-20260917-004',
        roomName: 'Room 34',
        rackIndex: 1,
        levelIndex: 2, // Level 3
        windowIndex: 4, // Window 5
        windowCode: 'R2-L3-W5',
        category: WindowIssueCategory.qa,
        title: 'Dry casing & heavy over-pinning',
        description:
            'Requires light spray at 1.5 L/m² and ambient RH inspection.',
        severity: 'normal',
        reporterName: 'Sarah (QA Inspector)',
        createdAt: now.subtract(const Duration(hours: 12)),
        status: 'open',
        temperature: 18.9,
        humidity: 86.5,
        co2: 1160.0,
        casingTemp: 19.4,
      ),
    ];
  }
}
