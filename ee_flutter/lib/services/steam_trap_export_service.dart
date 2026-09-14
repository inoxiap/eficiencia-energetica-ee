import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:excel/excel.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../domain/steam_trap_entry.dart';

class SteamTrapExportService {
  const SteamTrapExportService();

  Future<void> shareExcel(List<SteamTrapRecord> records) async {
    final bytes = _excel(records);
    await _share(
      bytes: bytes,
      fileName: 'trampas_vapor.xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> sharePhotoZip(List<SteamTrapRecord> records) async {
    final bytes = await _photoZip(records);
    await _share(
      bytes: bytes,
      fileName: 'fotografias_trampas.zip',
      mimeType: 'application/zip',
    );
  }

  Future<void> shareCombined(List<SteamTrapRecord> records) async {
    final excelBytes = _excel(records);
    final archive = Archive()
      ..addFile(
        ArchiveFile('trampas_vapor.xlsx', excelBytes.length, excelBytes),
      );
    await _addPhotos(archive, records, prefix: 'fotografias/');
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    await _share(
      bytes: bytes,
      fileName: 'levantamiento_trampas.zip',
      mimeType: 'application/zip',
    );
  }

  Uint8List _excel(List<SteamTrapRecord> records) {
    final workbook = Excel.createExcel();
    final sheet = workbook['Trampas'];
    sheet.appendRow([
      for (final label in const [
        'TAG',
        'Codigo seccion',
        'Seccion',
        'Zona',
        'Equipo o sistema',
        'Servicio',
        'Diametro',
        'Tipo de trampa',
        'Recuperacion condensado',
        'Diagnostico',
        'Estado',
        'Fecha',
        'Usuario',
        'Foto cercana',
        'Foto general',
        'Comentarios',
      ])
        TextCellValue(label),
    ]);
    for (final record in records) {
      sheet.appendRow([
        for (final value in [
          record.tag,
          record.sectionCode,
          record.sectionName,
          record.zone,
          record.equipmentName,
          record.serviceName,
          record.diameter,
          record.trapTypeName,
          record.condensateRecoveryId,
          record.diagnosisStatus,
          record.status,
          record.createdAt
              .toUtc()
              .subtract(const Duration(hours: 5))
              .toIso8601String(),
          record.ownerName,
          record.closePhoto?.url ?? '',
          record.generalPhoto?.url ?? '',
          record.comments,
        ])
          TextCellValue(value),
      ]);
    }
    if (workbook.tables.containsKey('Sheet1')) workbook.delete('Sheet1');
    return Uint8List.fromList(workbook.encode()!);
  }

  Future<Uint8List> _photoZip(List<SteamTrapRecord> records) async {
    final archive = Archive();
    await _addPhotos(archive, records);
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  Future<void> _addPhotos(
    Archive archive,
    List<SteamTrapRecord> records, {
    String prefix = '',
  }) async {
    for (final record in records) {
      for (final photo in [record.closePhoto, record.generalPhoto]) {
        if (photo == null || photo.url.isEmpty) continue;
        final response = await http.get(Uri.parse(photo.url));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final name = photo.fileName.isNotEmpty
            ? photo.fileName
            : '${record.tag}_${photo.type.toUpperCase()}.jpg';
        archive.addFile(
          ArchiveFile(
            '$prefix${record.tag}/$name',
            response.bodyBytes.length,
            response.bodyBytes,
          ),
        );
      }
    }
  }

  Future<void> _share({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType)],
        fileNameOverrides: [fileName],
        subject: 'Registros de trampas de vapor',
      ),
    );
  }
}
