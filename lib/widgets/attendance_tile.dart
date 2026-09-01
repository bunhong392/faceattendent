import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/attendance_model.dart';
import '../services/app_state.dart';
import '../utils/status_utils.dart';

class AttendanceTile extends StatelessWidget {
  final AttendanceRecord record;
  final VoidCallback? onDelete;
  const AttendanceTile({super.key, required this.record, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = StatusUtils.colorFor(record.status);
    final schedules = context.watch<AppState>().schedules;
    final lateBy = StatusUtils.lateDurationFor(record, schedules);
    final statusLabel = (record.status == AttendanceStatus.late && lateBy != null)
        ? 'Late (${StatusUtils.formatDuration(lateBy)})'
        : StatusUtils.labelFor(record.status);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(
              record.type == AttendanceType.checkIn ? Icons.login : Icons.logout,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${record.type == AttendanceType.checkIn ? "Check-in" : "Check-out"} • ${DateFormat('MMM d, h:mm a').format(record.timestamp)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (record.verification != VerificationResult.success)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      StatusUtils.verificationMessage(record.verification),
                      style: TextStyle(fontSize: 11, color: Colors.red.shade400),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(
              statusLabel,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
              tooltip: 'Delete record',
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}
