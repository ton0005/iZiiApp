import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/database/app_database.dart';

/// Service to generate professional A4 PDF printouts of the Daily Job Plan
/// for the Growing department (Mushroom Farm).
class DailyJobPlanPdfService {
  /// Displays the interactive print & export PDF preview modal
  static Future<void> printDailyPlan({
    required BuildContext context,
    required DateTime date,
    required List<MushroomJob> jobs,
    required List<GrowRoom> rooms,
    required List<Map<String, dynamic>> jobTypes,
    required List<Map<String, dynamic>> employees,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    await Printing.layoutPdf(
      name: 'Growing_Job_Plan_$dateStr.pdf',
      onLayout: (PdfPageFormat format) async {
        return generateDailyPlanPdfBytes(
          format: format,
          date: date,
          jobs: jobs,
          rooms: rooms,
          jobTypes: jobTypes,
          employees: employees,
        );
      },
    );
  }

  /// Generates the raw PDF bytes for the Daily Job Plan
  static Future<Uint8List> generateDailyPlanPdfBytes({
    required PdfPageFormat format,
    required DateTime date,
    required List<MushroomJob> jobs,
    required List<GrowRoom> rooms,
    required List<Map<String, dynamic>> jobTypes,
    required List<Map<String, dynamic>> employees,
  }) async {
    final pdf = pw.Document();

    // Attempt to load Google Fonts with Vietnamese / Unicode support;
    // gracefully fall back to built-in Helvetica if network unavailable.
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      fontRegular = await PdfGoogleFonts.robotoRegular();
      fontBold = await PdfGoogleFonts.robotoBold();
    } catch (_) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final roomNameById = <String, String>{};
    for (final r in rooms) {
      roomNameById[r.id] = r.name;
    }

    final jobTypeById = <String, Map<String, dynamic>>{};
    for (final jt in jobTypes) {
      jobTypeById[jt['id'].toString().toLowerCase()] = jt;
    }

    final empNameById = <String, String>{};
    for (final e in employees) {
      empNameById[e['id'].toString()] = e['name']?.toString() ?? e['id'].toString();
    }

    // Sort jobs by room, then by scheduled time / name
    final sortedJobs = List<MushroomJob>.from(jobs);
    sortedJobs.sort((a, b) {
      final roomA = roomNameById[a.roomId] ?? a.roomId;
      final roomB = roomNameById[b.roomId] ?? b.roomId;
      final cRoom = roomA.compareTo(roomB);
      if (cRoom != 0) return cRoom;
      return (a.scheduledAt ?? a.createdAt).compareTo(b.scheduledAt ?? b.createdAt);
    });

    final formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(date);
    final printTimestamp = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final totalJobs = sortedJobs.length;
    final assignedCount = sortedJobs.where((j) => j.assignee != null && j.assignee!.trim().isNotEmpty).length;
    final unassignedCount = totalJobs - assignedCount;
    final soloCount = sortedJobs.where((j) => j.isSoloJob == true || j.jobType == 'alone_worker').length;

    // Build PDF Document
    pdf.addPage(
      pw.MultiPage(
        pageFormat: format.copyWith(
          marginBottom: 20,
          marginLeft: 25,
          marginRight: 25,
          marginTop: 25,
        ),
        header: (pw.Context pageCtx) => _buildPdfHeader(
          formattedDate: formattedDate,
          totalJobs: totalJobs,
          assignedCount: assignedCount,
          unassignedCount: unassignedCount,
          soloCount: soloCount,
          fontBold: fontBold,
          fontRegular: fontRegular,
        ),
        footer: (pw.Context pageCtx) => _buildPdfFooter(
          pageCtx: pageCtx,
          printTimestamp: printTimestamp,
          fontRegular: fontRegular,
          fontBold: fontBold,
        ),
        build: (pw.Context pageCtx) => [
          pw.SizedBox(height: 10),
          _buildJobTable(
            jobs: sortedJobs,
            roomNameById: roomNameById,
            jobTypeById: jobTypeById,
            empNameById: empNameById,
            fontRegular: fontRegular,
            fontBold: fontBold,
          ),
          pw.SizedBox(height: 16),
          _buildSignOffSection(fontRegular, fontBold),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfHeader({
    required String formattedDate,
    required int totalJobs,
    required int assignedCount,
    required int unassignedCount,
    required int soloCount,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 1.5)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 8),
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'MUSHBOOM MONARTO - GROWING DAILY JOB PLAN',
                style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blueGrey900),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Date: $formattedDate',
                style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.indigo900),
              ),
            ],
          ),
          pw.Row(
            children: [
              _buildMetricChip('Total Jobs', '$totalJobs', PdfColors.blueGrey700, fontRegular, fontBold),
              pw.SizedBox(width: 6),
              _buildMetricChip('Assigned', '$assignedCount', PdfColors.green800, fontRegular, fontBold),
              pw.SizedBox(width: 6),
              _buildMetricChip('Unassigned', '$unassignedCount', PdfColors.orange800, fontRegular, fontBold),
              if (soloCount > 0) ...[
                pw.SizedBox(width: 6),
                _buildMetricChip('Solo Jobs', '$soloCount', PdfColors.red800, fontRegular, fontBold),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricChip(String label, String value, PdfColor color, pw.Font regular, pw.Font bold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: color.luminance > 0.5 ? PdfColors.grey100 : color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: color, width: 0.8),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label: ', style: pw.TextStyle(font: regular, fontSize: 8.5, color: PdfColors.white)),
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white)),
        ],
      ),
    );
  }

  static pw.Widget _buildJobTable({
    required List<MushroomJob> jobs,
    required Map<String, String> roomNameById,
    required Map<String, Map<String, dynamic>> jobTypeById,
    required Map<String, String> empNameById,
    required pw.Font fontRegular,
    required pw.Font fontBold,
  }) {
    if (jobs.isEmpty) {
      return pw.Center(
        child: pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Text(
            'No jobs planned for this date.',
            style: pw.TextStyle(font: fontRegular, fontSize: 12, color: PdfColors.grey700),
          ),
        ),
      );
    }

    final headers = [
      '#',
      'Room',
      'Job Name / Task',
      'Job Type',
      'Std (m)',
      'Assignee (Staff)',
      'Solo',
      'Notes',
      'Done [ ]',
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.6), // #
        1: pw.FlexColumnWidth(1.2), // Room
        2: pw.FlexColumnWidth(2.8), // Job Name
        3: pw.FlexColumnWidth(1.5), // Type
        4: pw.FlexColumnWidth(0.9), // Std min
        5: pw.FlexColumnWidth(2.0), // Assignee
        6: pw.FlexColumnWidth(0.8), // Solo
        7: pw.FlexColumnWidth(2.2), // Notes
        8: pw.FlexColumnWidth(0.9), // Done check
      },
      children: [
        // Table Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
          children: headers.map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              child: pw.Text(
                h,
                style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.blueGrey900),
                textAlign: h == '#' || h == 'Std (m)' || h == 'Solo' || h == 'Done [ ]'
                    ? pw.TextAlign.center
                    : pw.TextAlign.left,
              ),
            );
          }).toList(),
        ),

        // Table Rows
        ...jobs.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final j = entry.value;
          final room = roomNameById[j.roomId] ?? j.roomId;
          final jt = jobTypeById[j.jobType.toLowerCase()];
          final jtName = jt != null ? (jt['name']?.toString() ?? j.jobType) : j.jobType;
          final stdMin = j.timeLimitMinutes ?? (jt != null ? jt['plan_minutes'] : 30);
          final isSolo = j.isSoloJob == true || j.jobType == 'alone_worker';
          final assigneeName = (j.assignee != null && j.assignee!.trim().isNotEmpty)
              ? (empNameById[j.assignee!] ?? j.assignee!)
              : '________________';
          final notes = [
            if (j.planDetails != null && j.planDetails!.trim().isNotEmpty) j.planDetails!.trim(),
            if (j.prochlorazRate != null && j.prochlorazRate!.trim().isNotEmpty) j.prochlorazRate!.trim(),
          ].join(' · ');

          final isEven = entry.key % 2 == 0;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : PdfColors.grey50,
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                child: pw.Text('$idx', style: pw.TextStyle(font: fontRegular, fontSize: 8), textAlign: pw.TextAlign.center),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text(room, style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text(j.name, style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text(jtName, style: pw.TextStyle(font: fontRegular, fontSize: 8)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text('$stdMin', style: pw.TextStyle(font: fontRegular, fontSize: 8), textAlign: pw.TextAlign.center),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text(assigneeName, style: pw.TextStyle(font: fontRegular, fontSize: 8)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text(
                  isSolo ? 'YES' : '-',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 8,
                    color: isSolo ? PdfColors.red800 : PdfColors.grey700,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text(notes, style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColors.grey800)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Container(
                  alignment: pw.Alignment.center,
                  child: pw.Container(
                    width: 10,
                    height: 10,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildSignOffSection(pw.Font fontRegular, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Plan Prepared By (Manager):', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
              pw.SizedBox(height: 18),
              pw.Text('Signature: ______________________', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Supervisor / Lead Dispatch:', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
              pw.SizedBox(height: 18),
              pw.Text('Signature: ______________________', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Safety / Gas Audit Sign-off:', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
              pw.SizedBox(height: 18),
              pw.Text('Signature: ______________________', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter({
    required pw.Context pageCtx,
    required String printTimestamp,
    required pw.Font fontRegular,
    required pw.Font fontBold,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'iZiiApp Growing Management • Printed: $printTimestamp',
            style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${pageCtx.pageNumber} of ${pageCtx.pagesCount}',
            style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }
}
