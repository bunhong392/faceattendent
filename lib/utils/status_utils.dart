import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import '../models/schedule_model.dart';
import 'app_theme.dart';

class StatusUtils {
  static Color colorFor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return AppTheme.success;
      case AttendanceStatus.late:
        return AppTheme.warning;
      case AttendanceStatus.absent:
        return AppTheme.danger;
      case AttendanceStatus.leave:
        return Colors.blueGrey;
    }
  }

  static String labelFor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.leave:
        return 'Leave';
    }
  }

  static String verificationMessage(VerificationResult r) {
    switch (r) {
      case VerificationResult.success:
        return 'Face verified successfully';
      case VerificationResult.noFaceDetected:
        return 'No face detected — please center your face in the frame';
      case VerificationResult.multipleFacesDetected:
        return 'Multiple faces detected — only one person at a time';
      case VerificationResult.noMatch:
        return 'Face not recognized — no matching profile found';
      case VerificationResult.locationRejected:
        return 'You are outside the authorized location';
      case VerificationResult.deviceMismatch:
        return 'This face profile is bound to a different device';
      case VerificationResult.locationOff:
        return 'Turn on your device location to check in/out';
      case VerificationResult.alreadyRecorded:
        return 'Already recorded for this schedule today';
    }
  }

  /// Robustly parses various time string formats such as "15:00", "08:30", "3:00 PM",
  /// "3:00pm", "03:15 AM", "3:00", or "8:00" into [TimeOfDay].
  static TimeOfDay? parseTimeString(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final clean = timeStr.trim().toUpperCase();

    final isPm = clean.contains('PM');
    final isAm = clean.contains('AM');
    final digitsOnly = clean.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = digitsOnly.split(':');
    if (parts.isEmpty || parts[0].isEmpty) return null;

    int hour = int.tryParse(parts[0]) ?? 0;
    int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    if (isPm && hour < 12) {
      hour += 12;
    } else if (isAm && hour == 12) {
      hour = 0;
    }

    // Clamp hour and minute into valid ranges
    hour = hour.clamp(0, 23);
    minute = minute.clamp(0, 59);

    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Formats a time string into 12-hour format e.g. "03:00 PM"
  static String formatTimeString(String? timeStr) {
    final tod = parseTimeString(timeStr);
    if (tod == null) return timeStr ?? '';
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  /// How late a check-in [record] was against its schedule's start time, or
  /// null if it isn't late (on time / not a check-in / no schedule to
  /// compare against). Mirrors the overnight-safe logic used when the
  /// record's status was first computed, so the duration shown here always
  /// matches the "Late" label.
  static Duration? lateDurationFor(AttendanceRecord record, List<ScheduleItem> schedules) {
    if (record.type != AttendanceType.checkIn) return null;
    if (record.status != AttendanceStatus.late) return null;
    if (record.scheduleId == null) return null;
    ScheduleItem? schedule;
    for (final s in schedules) {
      if (s.id == record.scheduleId) {
        schedule = s;
        break;
      }
    }
    if (schedule == null) return null;

    final startTod = parseTimeString(schedule.startTime);
    if (startTod == null) return null;
    final endTod = parseTimeString(schedule.endTime);

    final ts = record.timestamp;
    var scheduledStart = DateTime(ts.year, ts.month, ts.day, startTod.hour, startTod.minute);

    if (endTod != null) {
      final crossesMidnight = (endTod.hour * 60 + endTod.minute) <= (startTod.hour * 60 + startTod.minute);
      if (crossesMidnight && (ts.hour * 60 + ts.minute) < (startTod.hour * 60 + startTod.minute)) {
        scheduledStart = scheduledStart.subtract(const Duration(days: 1));
      }
    }

    final diff = ts.difference(scheduledStart);
    return diff.isNegative ? null : diff;
  }

  /// Formats a [Duration] as "Xh Ym" (or just "Ym" under an hour), matching
  /// how "Late" durations are shown in the attendance timeline.
  static String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}
