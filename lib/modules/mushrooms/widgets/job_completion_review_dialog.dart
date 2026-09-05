// lib/modules/mushrooms/widgets/job_completion_review_dialog.dart
//
// Shared "Mark Done" confirmation used by every job checklist (mobile
// dashboard and desktop Growing tab). Exists because Supervisors routinely
// walk the floor doing the actual work, then batch-tap "Done" on several
// jobs back-to-back much later — which made every one of those jobs look
// Over Standard on the Growing Performance Board, even though the real
// work was finished on time. This lets the Supervisor confirm that at the
// moment of completion, so the board reflects reality instead of app
// data-entry lag.

import 'package:flutter/material.dart';
import '../models/growing_performance_models.dart';
import '../repository.dart';

/// Shows a review dialog only when marking the job Done *right now* would
/// make it look Over Standard. Returns:
/// - `true`  — proceed, Supervisor confirmed it was actually completed ON TIME
/// - `false` — proceed with no override (either it isn't late, or the
///             Supervisor confirmed it genuinely ran over)
/// - `null`  — cancelled, don't complete the job
Future<bool?> confirmJobCompletion(
  BuildContext context, {
  required String jobType,
  DateTime? startedAt,
  DateTime? createdAt,
}) async {
  final start = startedAt ?? createdAt ?? DateTime.now();
  final elapsedMinutes = DateTime.now().difference(start).inMinutes;

  int planMinutes;
  try {
    final types = await MushroomsRepository().getJobTypes();
    final match = types.where((t) => t['id'] == jobType);
    planMinutes = match.isNotEmpty
        ? match.first['plan_minutes'] as int
        : GrowingPerformanceConstants.jobTypeFor(jobType).planMinutes.round();
  } catch (_) {
    planMinutes = GrowingPerformanceConstants.jobTypeFor(jobType).planMinutes.round();
  }

  final grace = (planMinutes * 0.10).round();
  final wouldBeOverStandard = elapsedMinutes > planMinutes + grace;

  // Fast path: nothing to review, just complete.
  if (!wouldBeOverStandard || !context.mounted) return false;

  bool markOnTime = true;
  return showDialog<bool>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => AlertDialog(
        title: const Text('Xác nhận hoàn thành công việc'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Việc này đã bắt đầu $elapsedMinutes phút trước (tiêu chuẩn $planMinutes phút), '
              'nên nếu hoàn thành ngay bây giờ sẽ bị tính "Quá giờ chuẩn" trên Performance Board.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: markOnTime,
              title: const Text(
                'Job này thực tế đã hoàn thành ĐÚNG GIỜ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Chỉ do bấm Done trễ, không phải làm chậm — bỏ chọn nếu thực sự quá giờ.',
                style: TextStyle(fontSize: 11),
              ),
              onChanged: (v) => setDialogState(() => markOnTime = v ?? true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, null),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, markOnTime),
            child: const Text('Hoàn thành'),
          ),
        ],
      ),
    ),
  );
}
