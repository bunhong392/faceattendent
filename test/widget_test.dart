import 'package:flutter_test/flutter_test.dart';
import 'package:face_attendance_app/models/attendance_model.dart';
import 'package:face_attendance_app/models/schedule_model.dart';
import 'package:face_attendance_app/utils/status_utils.dart';

void main() {
  group('StatusUtils and Schedule Time Tests', () {
    test('parseTimeString parses various 12h and 24h formats correctly', () {
      final t1 = StatusUtils.parseTimeString('15:00');
      expect(t1, isNotNull);
      expect(t1!.hour, 15);
      expect(t1.minute, 0);

      final t2 = StatusUtils.parseTimeString('3:00 PM');
      expect(t2, isNotNull);
      expect(t2!.hour, 15);
      expect(t2.minute, 0);

      final t3 = StatusUtils.parseTimeString('3:15 pm');
      expect(t3, isNotNull);
      expect(t3!.hour, 15);
      expect(t3.minute, 15);

      final t4 = StatusUtils.parseTimeString('08:30');
      expect(t4, isNotNull);
      expect(t4!.hour, 8);
      expect(t4.minute, 30);

      final t5 = StatusUtils.parseTimeString('8:00 AM');
      expect(t5, isNotNull);
      expect(t5!.hour, 8);
      expect(t5.minute, 0);
    });

    test('formatTimeString formats time strings to readable 12-hour format', () {
      expect(StatusUtils.formatTimeString('15:00'), '3:00 PM');
      expect(StatusUtils.formatTimeString('08:30'), '8:30 AM');
      expect(StatusUtils.formatTimeString('12:00'), '12:00 PM');
    });

    test('lateDurationFor calculates correct late difference for 3:00 schedule and 3:15 check-in', () {
      final schedule = ScheduleItem(
        id: 'sched-1',
        title: 'Math Class',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        startTime: '15:00',
        endTime: '16:30',
        lateThresholdMinutes: 10,
      );

      final record = AttendanceRecord(
        id: 'att-1',
        userId: 'user-1',
        userName: 'Jamie Student',
        scheduleId: 'sched-1',
        timestamp: DateTime(2026, 8, 31, 15, 15),
        type: AttendanceType.checkIn,
        status: AttendanceStatus.late,
        verification: VerificationResult.success,
      );

      final duration = StatusUtils.lateDurationFor(record, [schedule]);
      expect(duration, isNotNull);
      expect(duration!.inMinutes, 15);
      expect(StatusUtils.formatDuration(duration), '15m');
    });

    test('lateDurationFor with 12-hour format "3:00 PM" startTime', () {
      final schedule = ScheduleItem(
        id: 'sched-2',
        title: 'Science Class',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        startTime: '3:00 PM',
        endTime: '4:00 PM',
        lateThresholdMinutes: 10,
      );

      final record = AttendanceRecord(
        id: 'att-2',
        userId: 'user-1',
        userName: 'Jamie Student',
        scheduleId: 'sched-2',
        timestamp: DateTime(2026, 8, 31, 15, 20),
        type: AttendanceType.checkIn,
        status: AttendanceStatus.late,
        verification: VerificationResult.success,
      );

      final duration = StatusUtils.lateDurationFor(record, [schedule]);
      expect(duration, isNotNull);
      expect(duration!.inMinutes, 20);
      expect(StatusUtils.formatDuration(duration), '20m');
    });
  });
}