import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:izii_app/core/database/database_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseBackupService backupService;

  setUp(() {
    backupService = DatabaseBackupService();
  });

  group('DatabaseBackupService Tests', () {
    test('getActiveDatabaseFile returns valid path', () async {
      final activeFile = await backupService.getActiveDatabaseFile();
      expect(activeFile.path, isNotEmpty);
      expect(activeFile.path.endsWith('.sqlite'), isTrue);
    });

    test('getBackupDirectory returns valid directory', () async {
      final backupDir = await backupService.getBackupDirectory();
      expect(backupDir.existsSync(), isTrue);
    });

    test('createBackup and listBackups test', () async {
      final activeFile = await backupService.getActiveDatabaseFile();
      if (!activeFile.existsSync()) {
        activeFile.parent.createSync(recursive: true);
        await activeFile.writeAsString('TEST_SQLITE_HEADER');
      }

      final backupFile = await backupService.createBackup(customName: 'test_backup_sample.sqlite');
      expect(backupFile, isNotNull);
      expect(backupFile!.existsSync(), isTrue);

      final list = await backupService.listBackups();
      expect(list.any((b) => b.fileName == 'test_backup_sample.sqlite'), isTrue);

      // Clean up test backup file
      if (backupFile.existsSync()) {
        await backupFile.delete();
      }
    });
  });
}
