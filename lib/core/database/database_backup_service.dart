import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Metadata representation of a Database Backup file.
class BackupFileInfo {
  final String path;
  final String fileName;
  final int sizeBytes;
  final DateTime modifiedAt;

  BackupFileInfo({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.modifiedAt,
  });
}

/// Service providing programmatic Backup & Restore functionality for iZiiApp SQLite Database.
class DatabaseBackupService {
  static final DatabaseBackupService _instance = DatabaseBackupService._internal();
  factory DatabaseBackupService() => _instance;
  DatabaseBackupService._internal();

  /// Gets the primary active database file path.
  Future<File> getActiveDatabaseFile() async {
    final envPath = Platform.environment['IZIIAPP_DB_PATH'];
    if (envPath != null && envPath.isNotEmpty) {
      return File(envPath);
    }
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? r'C:\Users\CHANH\AppData\Local';
      return File(p.join(localAppData, 'izii_app', 'data', 'izii_app_db.sqlite'));
    }
    final dbFolder = await getApplicationSupportDirectory();
    return File(p.join(dbFolder.path, 'izii_app_db.sqlite'));
  }

  /// Gets the directory where backups are stored.
  Future<Directory> getBackupDirectory() async {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? r'C:\Users\CHANH\AppData\Local';
      final dir = Directory(p.join(localAppData, 'izii_app', 'backups'));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    }
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'izii_app_backups'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Creates a timestamped backup copy of the active SQLite database file.
  Future<File?> createBackup({String? customName}) async {
    try {
      final dbFile = await getActiveDatabaseFile();
      if (!dbFile.existsSync()) {
        print('Database file does not exist at: ${dbFile.path}');
        return null;
      }

      final backupDir = await getBackupDirectory();
      final now = DateTime.now();
      final timestamp = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
      final name = customName ?? 'izii_app_db_backup_$timestamp.sqlite';
      final backupFile = File(p.join(backupDir.path, name));

      await dbFile.copy(backupFile.path);
      print('✅ Database backed up successfully to: ${backupFile.path}');
      return backupFile;
    } catch (e) {
      print('❌ Backup failed: $e');
      rethrow;
    }
  }

  /// Restores the database from a backup file path.
  Future<bool> restoreBackup(String backupFilePath) async {
    try {
      final backupFile = File(backupFilePath);
      if (!backupFile.existsSync()) {
        throw Exception('Backup file not found at: $backupFilePath');
      }

      final activeDbFile = await getActiveDatabaseFile();

      if (!activeDbFile.parent.existsSync()) {
        activeDbFile.parent.createSync(recursive: true);
      }

      await backupFile.copy(activeDbFile.path);
      print('✅ Database restored successfully from: $backupFilePath');
      return true;
    } catch (e) {
      print('❌ Restore failed: $e');
      rethrow;
    }
  }

  /// Lists all available database backups ordered from newest to oldest.
  Future<List<BackupFileInfo>> listBackups() async {
    final backupDir = await getBackupDirectory();
    if (!backupDir.existsSync()) return [];

    final files = backupDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sqlite') || f.path.endsWith('.bak'))
        .toList();

    final result = <BackupFileInfo>[];
    for (final f in files) {
      final stat = await f.stat();
      result.add(BackupFileInfo(
        path: f.path,
        fileName: p.basename(f.path),
        sizeBytes: stat.size,
        modifiedAt: stat.modified,
      ));
    }

    result.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return result;
  }
}
