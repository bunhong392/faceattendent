enum AttendanceType { checkIn, checkOut }

enum AttendanceStatus { present, late, absent, leave }

enum VerificationResult {
  success,
  noFaceDetected,
  multipleFacesDetected,
  noMatch,
  locationRejected,
  deviceMismatch,
  locationOff, // device GPS/location service was off — checked before face scan even starts
  alreadyRecorded, // this schedule already has a check-in/check-out of this type today
}

class AttendanceRecord {
  final String id;
  final String userId;
  final String userName; // denormalized for fast list rendering
  final String? scheduleId;
  final DateTime timestamp;
  final AttendanceType type;
  final AttendanceStatus status;
  final VerificationResult verification;
  final double? matchConfidence; // 0.0 - 1.0
  final double? latitude;
  final double? longitude;
  final String? deviceId; // device the attempt was made from, for audit/device validation
  final String? note;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.userName,
    this.scheduleId,
    required this.timestamp,
    required this.type,
    required this.status,
    required this.verification,
    this.matchConfidence,
    this.latitude,
    this.longitude,
    this.deviceId,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'scheduleId': scheduleId,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'status': status.name,
        'verification': verification.name,
        'matchConfidence': matchConfidence,
        'latitude': latitude,
        'longitude': longitude,
        'deviceId': deviceId,
        'note': note,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        id: json['id'],
        userId: json['userId'],
        userName: json['userName'],
        scheduleId: json['scheduleId'],
        timestamp: DateTime.parse(json['timestamp']),
        type: AttendanceType.values.firstWhere((t) => t.name == json['type']),
        status: AttendanceStatus.values.firstWhere((s) => s.name == json['status']),
        verification: VerificationResult.values.firstWhere((v) => v.name == json['verification']),
        matchConfidence: (json['matchConfidence'] as num?)?.toDouble(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        deviceId: json['deviceId'],
        note: json['note'],
      );
}
