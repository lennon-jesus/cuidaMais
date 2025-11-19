import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../db/dbhelper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

class BackupResult {
  final bool success;
  final String message;
  final String? filePath;

  BackupResult(this.success, this.message, {this.filePath});
}

class BackupService {
  Future<BackupResult> createBackup() async {
    try {
      final dbPath = await getDatabasesPath();
      final fullDbPath = p.join(dbPath, "medic.db");

      if (!await File(fullDbPath).exists()) {
        return BackupResult(false, "Banco de dados não encontrado.");
      }

      final tempDir = Directory.systemTemp.path;
      final backupZipTemp = p.join(tempDir, "backup_cuida_plus.zip");

      final encoder = ZipFileEncoder();
      encoder.create(backupZipTemp);
      encoder.addFile(File(fullDbPath));
      encoder.close();

      final fileBytes = await File(backupZipTemp).readAsBytes();

      final params = SaveFileDialogParams(
        data: fileBytes,
        fileName: "backup_cuida_mais.zip",
      );

      final savedPath = await FlutterFileDialog.saveFile(params: params);

      if (savedPath == null) {
        return BackupResult(false, "Backup cancelado pelo usuário.");
      }

      return BackupResult(true, "Backup salvo com sucesso!", filePath: savedPath);
    } catch (e) {
      return BackupResult(false, "Erro ao criar backup: $e");
    }
  }

  Future<String?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["zip"],
    );

    if (result == null) return null;
    return result.files.single.path;
  }

  Future<BackupResult> restoreFromZip(String zipPath) async {
    try {
      final dbPath = await getDatabasesPath();
      final fullDbPath = p.join(dbPath, "medic.db");

      await DatabaseHelper().closeDB();

      final bytes = File(zipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (var file in archive) {
        if (file.isFile && file.name.contains(".db")) {
          final data = file.content as List<int>;
          final outFile = File(fullDbPath);
          await outFile.writeAsBytes(data, flush: true);
        }
      }

      return BackupResult(true, "Backup restaurado com sucesso!");
    } catch (e) {
      return BackupResult(false, "Erro ao restaurar backup: $e");
    }
  }

  Future<BackupResult> resetAppToDefaults() async {
    try {
      final dbPath = await getDatabasesPath();
      final fullDbPath = p.join(dbPath, "medic.db");

      await DatabaseHelper().closeDB();

      if (await File(fullDbPath).exists()) {
        await File(fullDbPath).delete();
      }

      await DatabaseHelper().database;

      return BackupResult(true, "Aplicativo resetado com sucesso.");
    } catch (e) {
      return BackupResult(false, "Erro ao resetar: $e");
    }
  }
}
