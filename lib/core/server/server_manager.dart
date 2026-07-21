import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

/// Server lifecycle status.
enum ServerStatus {
  stopped,
  starting,
  running,
  stopping,
  error,
}

/// Manages the lifecycle of the embedded iziiapp_server.exe process.
///
/// This service handles:
/// - Start/Stop of the Uvicorn ASGI server process
/// - Health check via periodic pings to /sync/status
/// - Auto-restart on crash (configurable)
/// - Real-time log streaming from stdout/stderr
/// - Server information (port, uptime, connected devices)
class ServerManager extends ChangeNotifier {
  // Singleton
  static final ServerManager _instance = ServerManager._internal();
  factory ServerManager() => _instance;
  ServerManager._internal();

  // ── State ──────────────────────────────────────────────────────────────────
  Process? _serverProcess;
  ServerStatus _status = ServerStatus.stopped;
  DateTime? _startedAt;
  int _port = 8080;
  bool _autoRestart = true;
  int _restartCount = 0;
  static const int _maxAutoRestarts = 5;

  // ── Log Stream ─────────────────────────────────────────────────────────────
  final _logController = StreamController<String>.broadcast();
  final List<String> _logBuffer = [];
  static const int _maxLogLines = 500;

  // ── Health Check ───────────────────────────────────────────────────────────
  Timer? _healthCheckTimer;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 3),
  ));

  // ── Public Getters ─────────────────────────────────────────────────────────
  ServerStatus get status => _status;
  bool get isRunning => _status == ServerStatus.running;
  int get port => _port;
  bool get autoRestart => _autoRestart;
  int get restartCount => _restartCount;
  DateTime? get startedAt => _startedAt;
  Stream<String> get logStream => _logController.stream;
  List<String> get logBuffer => List.unmodifiable(_logBuffer);

  /// Human-readable uptime string.
  String get uptimeString {
    if (_startedAt == null) return '--';
    final elapsed = DateTime.now().difference(_startedAt!);
    if (elapsed.inHours > 0) {
      return '${elapsed.inHours}h ${elapsed.inMinutes.remainder(60)}m';
    } else if (elapsed.inMinutes > 0) {
      return '${elapsed.inMinutes}m ${elapsed.inSeconds.remainder(60)}s';
    }
    return '${elapsed.inSeconds}s';
  }

  /// Resolves the path to iziiapp_server.exe relative to the Flutter app.
  String get _serverExePath {
    final appDir = path.dirname(Platform.resolvedExecutable);
    // In development, the server binary is at: dist/iziiapp_server.exe or server/
    // In production, it sits alongside the Flutter exe
    final candidates = [
      path.join(appDir, 'server', 'dist', 'izii_server', 'izii_server.exe'),
      path.join(appDir, 'server', 'izii_server.exe'),
      path.join(appDir, 'server', 'iziiapp_server.exe'),
      path.join(appDir, 'izii_server.exe'),
      path.join(appDir, 'iziiapp_server.exe'),
      path.join(appDir, '..', 'server', 'dist', 'izii_server', 'izii_server.exe'),
      path.join(appDir, '..', '..', 'server', 'dist', 'izii_server', 'izii_server.exe'),
      path.join(appDir, '..', 'dist', 'iziiapp_server.exe'),
      path.join(appDir, '..', '..', 'dist', 'iziiapp_server.exe'),
    ];

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    // Final fallback
    return path.join(appDir, 'server', 'dist', 'izii_server', 'izii_server.exe');
  }

  /// The working directory for the server process (where data/ folder lives).
  String get _serverWorkDir => path.dirname(_serverExePath);

  /// The base URL for API calls.
  String get serverUrl => 'http://127.0.0.1:$_port';

  // ══════════════════════════════════════════════════════════════════════════
  //  Start / Stop / Restart
  // ══════════════════════════════════════════════════════════════════════════

  /// Start the server process.
  ///
  /// Returns `true` if the server started successfully and is responding
  /// to health checks within the timeout period.
  Future<bool> startServer({int? port}) async {
    if (_status == ServerStatus.running || _status == ServerStatus.starting) {
      _log('⚠️ Server is already ${_status.name}');
      return _status == ServerStatus.running;
    }

    if (port != null) _port = port;
    _setStatus(ServerStatus.starting);
    _log('🚀 Starting iZiiApp Server on port $_port...');

    final exePath = _serverExePath;
    if (!File(exePath).existsSync()) {
      _log('❌ Server executable not found at: $exePath');
      _setStatus(ServerStatus.error);
      return false;
    }

    try {
      _serverProcess = await Process.start(
        exePath,
        [],
        workingDirectory: _serverWorkDir,
        environment: {'PYTHONIOENCODING': 'utf-8'},
      );

      _log('📦 Process started (PID: ${_serverProcess!.pid})');

      // Stream stdout
      _serverProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) => _log('[SERVER] $line'),
        onError: (e) => _log('⚠️ stdout error: $e'),
      );

      // Stream stderr
      _serverProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) => _log('[STDERR] $line'),
        onError: (e) => _log('⚠️ stderr error: $e'),
      );

      // Monitor process exit
      _serverProcess!.exitCode.then((exitCode) {
        _log('🛑 Server process exited with code: $exitCode');
        final wasRunning = _status == ServerStatus.running;
        _setStatus(ServerStatus.stopped);
        _healthCheckTimer?.cancel();
        _serverProcess = null;

        // Auto-restart if configured and was running (i.e., crash, not manual stop)
        if (wasRunning &&
            _autoRestart &&
            _restartCount < _maxAutoRestarts) {
          _restartCount++;
          _log('🔄 Auto-restart attempt $_restartCount/$_maxAutoRestarts...');
          Future.delayed(const Duration(seconds: 2), () => startServer());
        }
      });

      // Wait for server to become ready
      final ready = await _waitForReady(timeout: const Duration(seconds: 25));

      if (ready) {
        _startedAt = DateTime.now();
        _restartCount = 0;
        _setStatus(ServerStatus.running);
        _startHealthCheck();
        _log('✅ Server is running at $serverUrl');
        return true;
      } else {
        _log('❌ Server failed to respond within timeout');
        await stopServer();
        _setStatus(ServerStatus.error);
        return false;
      }
    } catch (e) {
      _log('❌ Failed to start server: $e');
      _setStatus(ServerStatus.error);
      return false;
    }
  }

  /// Stop the server process gracefully.
  Future<void> stopServer() async {
    if (_serverProcess == null) {
      _setStatus(ServerStatus.stopped);
      return;
    }

    _setStatus(ServerStatus.stopping);
    _log('🛑 Stopping server (PID: ${_serverProcess!.pid})...');
    _healthCheckTimer?.cancel();

    // Disable auto-restart during manual stop
    final savedAutoRestart = _autoRestart;
    _autoRestart = false;

    try {
      _serverProcess!.kill(ProcessSignal.sigterm);
      // Give it 3 seconds to shut down gracefully
      await _serverProcess!.exitCode.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          _log('⚠️ Graceful shutdown timed out, forcing kill...');
          _serverProcess!.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    } catch (e) {
      _log('⚠️ Error during stop: $e');
    }

    _serverProcess = null;
    _startedAt = null;
    _autoRestart = savedAutoRestart;
    _setStatus(ServerStatus.stopped);
    _log('✅ Server stopped');
  }

  /// Restart the server.
  Future<bool> restartServer() async {
    _log('🔄 Restarting server...');
    await stopServer();
    await Future.delayed(const Duration(seconds: 1));
    return startServer();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Health Check
  // ══════════════════════════════════════════════════════════════════════════

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _performHealthCheck(),
    );
  }

  Future<void> _performHealthCheck() async {
    try {
      final response = await _dio.get('$serverUrl/sync/status');
      if (response.statusCode == 200 && _status != ServerStatus.running) {
        _setStatus(ServerStatus.running);
      }
    } catch (e) {
      if (_status == ServerStatus.running) {
        _log('⚠️ Health check failed: server unreachable');
        // Don't immediately set to error — could be a transient glitch
      }
    }
  }

  /// Polls the server until it responds or the timeout elapses.
  Future<bool> _waitForReady({required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final response = await _dio.get('$serverUrl/sync/status');
        if (response.statusCode == 200) return true;
      } catch (_) {
        // Server not ready yet
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// Fetches live server status (total synced records, connected tables).
  Future<Map<String, dynamic>?> fetchServerStatus() async {
    if (!isRunning) return null;
    try {
      final response = await _dio.get('$serverUrl/sync/status');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Fetches count of online devices.
  Future<int> fetchOnlineDeviceCount() async {
    if (!isRunning) return 0;
    try {
      final response = await _dio.get('$serverUrl/api/v1/devices/online');
      final devices = response.data['devices'] as List? ?? [];
      return devices.length;
    } catch (e) {
      return 0;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Configuration
  // ══════════════════════════════════════════════════════════════════════════

  set autoRestart(bool value) {
    _autoRestart = value;
    notifyListeners();
  }

  set port(int value) {
    if (_status == ServerStatus.running) {
      _log('⚠️ Cannot change port while server is running');
      return;
    }
    _port = value;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Logging
  // ══════════════════════════════════════════════════════════════════════════

  void _log(String message) {
    final timestamped =
        '[${DateTime.now().toIso8601String().substring(11, 19)}] $message';
    _logBuffer.add(timestamped);
    if (_logBuffer.length > _maxLogLines) {
      _logBuffer.removeAt(0);
    }
    if (!_logController.isClosed) {
      _logController.add(timestamped);
    }
    if (kDebugMode) {
      // ignore: avoid_print
      print(timestamped);
    }
  }

  void clearLogs() {
    _logBuffer.clear();
    notifyListeners();
  }

  void _setStatus(ServerStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  /// Check if this platform supports embedded server (Windows desktop only).
  static bool get isSupported =>
      !kIsWeb && Platform.isWindows;
}
