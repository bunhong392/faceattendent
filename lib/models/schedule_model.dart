/// Defines when/where attendance is expected — a class period or a work shift.
class ScheduleItem {
  final String id;
  final String title; // e.g. "Mathematics 101" or "Morning Shift"
  final String? className;
  final String? subject;
  final String? department;
  final String? room;
  final List<int> weekdays; // 1 = Monday ... 7 = Sunday
  final String startTime; // "08:00"
  final String endTime; // "09:30"
  final String? location;
  final double? latitude;
  final double? longitude;
  final double? radiusMeters; // geofence radius, null = no GPS restriction
  final int lateThresholdMinutes; // minutes after start considered "late"

  // Directly assigns this schedule to specific employees/students, instead
  // of (or in addition to) matching everyone in a class/department. Empty
  // means "match by className/department" (the original behavior).
  final List<String> assignedUserIds;

  ScheduleItem({
    required this.id,
    required this.title,
    this.className,
    this.subject,
    this.department,
    this.room,
    required this.weekdays,
    required this.startTime,
    required this.endTime,
    this.location,
    this.latitude,
    this.longitude,
    this.radiusMeters,
    this.lateThresholdMinutes = 10,
    this.assignedUserIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'className': className,
        'subject': subject,
        'department': department,
        'room': room,
        'weekdays': weekdays,
        'startTime': startTime,
        'endTime': endTime,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'lateThresholdMinutes': lateThresholdMinutes,
        'assignedUserIds': assignedUserIds,
      };

  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
        id: json['id'],
        title: json['title'],
        className: json['className'],
        subject: json['subject'],
        department: json['department'],
        room: json['room'],
        weekdays: List<int>.from(json['weekdays']),
        startTime: json['startTime'],
        endTime: json['endTime'],
        location: json['location'],
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        radiusMeters: (json['radiusMeters'] as num?)?.toDouble(),
        lateThresholdMinutes: json['lateThresholdMinutes'] ?? 10,
        assignedUserIds: json['assignedUserIds'] != null ? List<String>.from(json['assignedUserIds']) : const [],
      );
}
