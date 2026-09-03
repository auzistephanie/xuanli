import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/data_backup.dart';
import 'storage_service.dart';

typedef BackupSharer = Future<void> Function(
  Uint8List bytes,
  String filename,
  Rect? shareOrigin,
);
typedef BackupPicker = Future<Uint8List?> Function();

class DataTransferService {
  final StorageService storage;
  final BackupSharer _share;
  final BackupPicker _pick;

  DataTransferService({
    StorageService? storage,
    BackupSharer? share,
    BackupPicker? pick,
  })  : storage = storage ?? StorageService(),
        _share = share ?? _shareWithSystem,
        _pick = pick ?? _pickWithSystem;

  Future<void> exportBackup({Rect? shareOrigin, DateTime? now}) async {
    final backup = await storage.buildBackup(now: now);
    final bytes = Uint8List.fromList(utf8.encode(backup.encode()));
    final date = backup.exportedAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final filename = 'xuanli-backup-${date.year}${two(date.month)}${two(date.day)}.json';
    await _share(bytes, filename, shareOrigin);
  }

  Future<XuanLiBackup?> pickBackup() async {
    final bytes = await _pick();
    if (bytes == null) return null;
    try {
      return XuanLiBackup.decode(utf8.decode(bytes));
    } on FormatException {
      throw const BackupFormatException('檔案文字編碼唔正確');
    }
  }

  Future<void> importBackup(XuanLiBackup backup) => storage.replaceWithBackup(backup);

  static Future<void> _shareWithSystem(
    Uint8List bytes,
    String filename,
    Rect? shareOrigin,
  ) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, name: filename, mimeType: 'application/json')],
      fileNameOverrides: [filename],
      title: '匯出玄曆資料',
      sharePositionOrigin: shareOrigin,
    ));
  }

  static Future<Uint8List?> _pickWithSystem() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    return file?.readAsBytes();
  }
}
