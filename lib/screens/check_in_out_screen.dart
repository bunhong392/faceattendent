import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/app_state.dart';
import '../services/location_service.dart';
import '../services/device_service.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import '../models/schedule_model.dart';
import '../utils/status_utils.dart';
import 'face_capture_screen.dart';
import 'face_registration_screen.dart';

/// Entry point for members to check in/out, and for admins to run a kiosk-
/// style "walk up and verify" flow. Routes into the shared camera capture
/// screen, which detects a face, extracts a descriptor, and hands it back
/// here for matching + attendance recording.
class CheckInOutScreen extends StatefulWidget {
  const CheckInOutScreen({super.key});

  @override
  State<CheckInOutScreen> createState() => _CheckInOutScreenState();
}

class _CheckInOutScreenState extends State<CheckInOutScreen> {
  AttendanceRecord? _lastResult;

  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    // Ticks every second so the clock shown on the check-in button always
    // matches the phone's real, current time.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String get _timeLabel {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get _secondsLabel => _now.second.toString().padLeft(2, '0');

  AttendanceType _currentType(AppState state) {
    final user = state.currentUser;
    if (user == null) return AttendanceType.checkIn;
    return state.getAutoAttendanceType(user.id);
  }

  Future<void> _startVerification() async {
    final state = context.read<AppState>();

    // Employees/students must have device location turned on *before* they
    // can even attempt a face scan — regardless of whether the specific
    // schedule enforces a GPS geofence.
    if (state.currentUser != null && state.currentUser!.role == UserRole.member) {
      final readiness = await LocationService.checkReadiness();
      if (!mounted) return;
      if (readiness != LocationReadiness.ready) {
        await _showLocationRequiredDialog(readiness);
        return;
      }
    }

    if (!mounted) return;

    if (state.currentUser != null && !state.currentUser!.hasFaceProfile) {
      final go = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No face profile yet'),
          content: const Text('You need to register your face before you can check in or out. Register now?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Register')),
          ],
        ),
      );
      if (!mounted) return;
      if (go == true) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FaceRegistrationScreen()));
      }
      return;
    }

    if (!mounted) return;

    final descriptor = await Navigator.of(context).push<List<double>?>(
      MaterialPageRoute(builder: (_) => const FaceCaptureScreen(mode: FaceCaptureMode.verify)),
    );

    if (!mounted) return;
    if (descriptor == null) return; // user cancelled or capture failed silently

    final match = state.identify(descriptor);
    late AttendanceRecord result;

    if (match == null) {
      // No confident match — record a rejected attempt for audit purposes if
      // we know who *should* be attempting (self-service kiosk uses currentUser).
      final user = state.currentUser;
      if (user == null) return;
      final typeToUse = _currentType(state);
      result = await state.recordAttendance(
        user: user,
        type: typeToUse,
        verification: VerificationResult.noMatch,
      );
    } else {
      final AppUser matchedUser = match.key;
      // Automatically determine the type for this user based on today's attendance history
      final typeToUse = state.getAutoAttendanceType(matchedUser.id);

      // Smart schedule resolution: matches assigned schedules, class/dept schedules,
      // general schedules, and picks the active/closest one for current time.
      final ScheduleItem? schedule = state.findScheduleForUser(matchedUser, time: DateTime.now(), type: typeToUse);

      // Enforce "one check-in and one check-out per schedule per day"
      if (state.hasAlreadyRecordedToday(userId: matchedUser.id, type: typeToUse, scheduleId: schedule?.id)) {
        result = await state.recordAttendance(
          user: matchedUser,
          type: typeToUse,
          verification: VerificationResult.alreadyRecorded,
          matchConfidence: match.value,
          scheduleId: schedule?.id,
        );
        if (mounted) {
          setState(() {
            _lastResult = result;
          });
        }
        return;
      }

      final deviceId = await DeviceService.getDeviceId();

      // Device validation: if bound to another device, reject
      if (deviceId != null && matchedUser.boundDeviceId != null && matchedUser.boundDeviceId != deviceId) {
        result = await state.recordAttendance(
          user: matchedUser,
          type: typeToUse,
          verification: VerificationResult.deviceMismatch,
          matchConfidence: match.value,
          scheduleId: schedule?.id,
          deviceId: deviceId,
        );
        if (mounted) {
          setState(() {
            _lastResult = result;
          });
        }
        return;
      }
      if (deviceId != null && matchedUser.boundDeviceId == null) {
        await state.bindDeviceIfUnset(matchedUser.id, deviceId);
      }

      // Target geofence can come from either assigned schedule or user's assigned branch
      final branch = matchedUser.branchId != null ? state.branchById(matchedUser.branchId!) : null;
      final double? targetLat = schedule?.latitude ?? branch?.latitude;
      final double? targetLng = schedule?.longitude ?? branch?.longitude;
      final double? targetRadius = schedule?.radiusMeters ?? branch?.radiusMeters;
      final requiresGps = targetLat != null && targetLng != null && targetRadius != null;

      double? lat;
      double? lng;

      if (requiresGps) {
        final position = await LocationService.getCurrentPosition();
        if (position == null) {
          result = await state.recordAttendance(
            user: matchedUser,
            type: typeToUse,
            verification: VerificationResult.locationRejected,
            matchConfidence: match.value,
            scheduleId: schedule?.id,
            deviceId: deviceId,
          );
          if (mounted) {
            setState(() {
              _lastResult = result;
            });
          }
          return;
        }
        lat = position.latitude;
        lng = position.longitude;
        final inside = LocationService.isWithinGeofence(
          position: position,
          targetLat: targetLat,
          targetLng: targetLng,
          radiusMeters: targetRadius,
        );
        if (!inside) {
          result = await state.recordAttendance(
            user: matchedUser,
            type: typeToUse,
            verification: VerificationResult.locationRejected,
            matchConfidence: match.value,
            scheduleId: schedule?.id,
            latitude: lat,
            longitude: lng,
            deviceId: deviceId,
          );
          if (mounted) {
            setState(() {
              _lastResult = result;
            });
          }
          return;
        }
      }

      result = await state.recordAttendance(
        user: matchedUser,
        type: typeToUse,
        verification: VerificationResult.success,
        matchConfidence: match.value,
        scheduleId: schedule?.id,
        latitude: lat,
        longitude: lng,
        deviceId: deviceId,
      );
    }

    if (mounted) {
      setState(() {
        _lastResult = result;
      });
    }
  }

  Future<void> _showLocationRequiredDialog(LocationReadiness readiness) async {
    final isServiceOff = readiness == LocationReadiness.serviceDisabled;
    final isPermanentlyDenied = readiness == LocationReadiness.permissionDeniedForever;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Turn on location'),
        content: Text(
          isServiceOff
              ? 'Please turn on your device location (GPS) before checking in or out.'
              : isPermanentlyDenied
                  ? 'Location permission was denied. Please allow location access for this app in Settings before checking in or out.'
                  : 'This app needs permission to use your location before checking in or out.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (isServiceOff) {
                await LocationService.openLocationSettings();
              } else if (isPermanentlyDenied) {
                await LocationService.openAppSettings();
              }
            },
            child: Text(isServiceOff || isPermanentlyDenied ? 'Open Settings' : 'Allow'),
          ),
        ],
      ),
    );
  }

  /// Builds today's check-in/check-out timeline entries for the signed-in
  /// user: each successful record gets an ordinal label ("1st Check-in",
  /// "2nd Check-out", ...) in chronological order, plus one trailing
  /// "upcoming" placeholder for whichever action (check-in/out) comes next.
  List<_TimelineEntry> _buildTimelineEntries(AppState state, AttendanceType nextType) {
    final user = state.currentUser;
    if (user == null) return [];
    final now = DateTime.now();
    final todays = state.attendance
        .where((a) =>
            a.userId == user.id &&
            a.verification == VerificationResult.success &&
            a.timestamp.year == now.year &&
            a.timestamp.month == now.month &&
            a.timestamp.day == now.day)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final entries = <_TimelineEntry>[];
    int checkInCount = 0;
    int checkOutCount = 0;
    for (final r in todays) {
      if (r.type == AttendanceType.checkIn) {
        checkInCount++;
        entries.add(_TimelineEntry(
          label: '${_ordinal(checkInCount)} Check-in',
          record: r,
        ));
      } else {
        checkOutCount++;
        entries.add(_TimelineEntry(
          label: '${_ordinal(checkOutCount)} Check-out',
          record: r,
        ));
      }
    }

    // Trailing placeholder: whichever action is expected next
    final nextLabel = nextType == AttendanceType.checkIn
        ? '${_ordinal(checkInCount + 1)} Check-in'
        : '${_ordinal(checkOutCount + 1)} Check-out';
    entries.add(_TimelineEntry(label: nextLabel, record: null));

    return entries;
  }

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

   Widget _buildTimelineCard(List<_TimelineEntry> entries) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final now = DateTime.now();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('d MMMM yyyy').format(now), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          for (int i = 0; i < entries.length; i++) ...[
            _buildTimelineRow(entries[i], state),
            if (i != entries.length - 1) const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineRow(_TimelineEntry entry, AppState state) {
    final record = entry.record;
    final isPending = record == null;
    final isCheckIn = entry.label.contains('Check-in');

    Widget statusWidget;
    if (isPending) {
      statusWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Next', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600)),
      );
    } else if (isCheckIn && record.status == AttendanceStatus.late) {
      final lateBy = StatusUtils.lateDurationFor(record, state.schedules);
      statusWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red)),
          const SizedBox(width: 6),
          Text(
            lateBy != null ? 'Late ${StatusUtils.formatDuration(lateBy)}' : 'Late',
            style: const TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      );
    } else {
      statusWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF22C55E))),
          const SizedBox(width: 6),
          const Text('Good', style: TextStyle(fontSize: 14, color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isPending ? Colors.blue : Colors.grey.shade400)),
            const SizedBox(width: 10),
            Text('${entry.label} :', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(width: 10),
            statusWidget,
          ],
        ),
        if (record != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Text(
              'Time : ${DateFormat('hh:mm a').format(record.timestamp)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currentType = _currentType(state);
    final isCheckIn = currentType == AttendanceType.checkIn;
    final todaysEntries = _buildTimelineEntries(state, currentType);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryThemeColor = isCheckIn ? const Color(0xFF059669) : const Color(0xFF2563EB);
    final buttonBgColor = isCheckIn
        ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF));
    final buttonBorderColor = isCheckIn ? const Color(0xFF10B981) : const Color(0xFF3B82F6);
    final actionLabel = isCheckIn ? 'Check in' : 'Check out';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Check-in / Check-out'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(state.isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round),
            tooltip: state.isDarkMode ? 'Bright Mode' : 'Dark Mode',
            onPressed: () => state.toggleTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            if (state.currentUser != null) ...[
              _buildTimelineCard(todaysEntries),
              const SizedBox(height: 28),
            ],

            // Big Dynamic Face Scan Circle Button with prominent Check in / Check out word
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _startVerification,
                    child: Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: buttonBgColor,
                        border: Border.all(color: buttonBorderColor.withValues(alpha: 0.5), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: buttonBorderColor.withValues(alpha: isDark ? 0.2 : 0.25),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                            size: 38,
                            color: buttonBorderColor,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isCheckIn ? 'CHECK IN' : 'CHECK OUT',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: buttonBorderColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _timeLabel,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey.shade300 : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                ':$_secondsLabel',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: buttonBorderColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Tap to Scan Face',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: buttonBorderColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Auto mode: Tap circle to $actionLabel',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_lastResult != null) _buildResultCard(_lastResult!),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(AttendanceRecord record) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final isSuccess = record.verification == VerificationResult.success;
    final isLate = record.status == AttendanceStatus.late;
    final color = StatusUtils.colorFor(record.status);
    final schedule = record.scheduleId != null ? state.scheduleById(record.scheduleId!) : null;
    final lateDuration = StatusUtils.lateDurationFor(record, state.schedules);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSuccess ? (isLate ? Icons.alarm : Icons.check_circle_rounded) : Icons.error_outline_rounded,
              color: color,
              size: 32,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isSuccess
                ? '${record.userName} — ${record.type == AttendanceType.checkIn ? "Check-in" : "Check-out"}'
                : 'Verification Failed',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (isSuccess && isLate) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                lateDuration != null
                    ? 'LATE BY ${StatusUtils.formatDuration(lateDuration).toUpperCase()}'
                    : 'RECORDED AS LATE',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
            if (schedule != null)
              Text(
                'Schedule "${schedule.title}" started at ${StatusUtils.formatTimeString(schedule.startTime)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ] else if (isSuccess) ...[
            Text(
              '${record.type == AttendanceType.checkIn ? "Checked in successfully" : "Checked out successfully"} • ${DateFormat('hh:mm a').format(record.timestamp)}',
              style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ] else ...[
            Text(
              StatusUtils.verificationMessage(record.verification),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
          if (record.matchConfidence != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Face match confidence: ${(record.matchConfidence! * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single row in the check-in/out timeline card: either a completed
/// [record] (with its ordinal label, e.g. "1st Check-in") or a pending
/// placeholder (record == null) showing what's expected next.
class _TimelineEntry {
  final String label;
  final AttendanceRecord? record;
  _TimelineEntry({required this.label, required this.record});
}
