enum UserRole { admin, member }

/// Represents a person tracked by the system: a student, teacher, or employee.
class AppUser {
  final String id; // internal uuid
  final String identificationNumber; // student ID / employee ID
  final String name;
  final String gender;
  final UserRole role;
  final String? phoneNumber; // for admin "call employee" action

  // Educational context (nullable — used when organization type is "school")
  final String? className;
  final String? group;
  final String? subject;
  final String? room;

  // Workplace context (nullable — used when organization type is "work")
  final String? department;
  final String? position;
  final String? branchId; // link to Branch, for multi-location companies

  final String? faceProfileId; // link to FaceProfile, null if not registered yet
  final String? boundDeviceId; // device the face profile was enrolled on, used for device validation
  final String? photoUrl; // self-uploaded profile picture (Cloudinary URL), null if not set
  final String email;
  final DateTime createdAt;

  // Set when an admin created this account (vs. self-registration) — used
  // to show the auto-generated login email/password once, right after
  // creation, so the admin can hand it to the employee.
  final bool createdByAdmin;

  AppUser({
    required this.id,
    required this.identificationNumber,
    required this.name,
    required this.gender,
    required this.role,
    this.phoneNumber,
    this.className,
    this.group,
    this.subject,
    this.room,
    this.department,
    this.position,
    this.branchId,
    this.faceProfileId,
    this.boundDeviceId,
    this.photoUrl,
    required this.email,
    required this.createdAt,
    this.createdByAdmin = false,
  });

  bool get hasFaceProfile => faceProfileId != null;

  AppUser copyWith({
    String? name,
    String? gender,
    String? phoneNumber,
    String? className,
    String? group,
    String? subject,
    String? room,
    String? department,
    String? position,
    String? branchId,
    String? faceProfileId,
    String? boundDeviceId,
    String? photoUrl,
  }) {
    return AppUser(
      id: id,
      identificationNumber: identificationNumber,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      role: role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      className: className ?? this.className,
      group: group ?? this.group,
      subject: subject ?? this.subject,
      room: room ?? this.room,
      department: department ?? this.department,
      position: position ?? this.position,
      branchId: branchId ?? this.branchId,
      faceProfileId: faceProfileId ?? this.faceProfileId,
      boundDeviceId: boundDeviceId ?? this.boundDeviceId,
      photoUrl: photoUrl ?? this.photoUrl,
      email: email,
      createdAt: createdAt,
      createdByAdmin: createdByAdmin,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'identificationNumber': identificationNumber,
        'name': name,
        'gender': gender,
        'role': role.name,
        'phoneNumber': phoneNumber,
        'className': className,
        'group': group,
        'subject': subject,
        'room': room,
        'department': department,
        'position': position,
        'branchId': branchId,
        'faceProfileId': faceProfileId,
        'boundDeviceId': boundDeviceId,
        'photoUrl': photoUrl,
        'email': email,
        'createdAt': createdAt.toIso8601String(),
        'createdByAdmin': createdByAdmin,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'],
        identificationNumber: json['identificationNumber'],
        name: json['name'],
        gender: json['gender'],
        role: UserRole.values.firstWhere((r) => r.name == json['role']),
        phoneNumber: json['phoneNumber'],
        className: json['className'],
        group: json['group'],
        subject: json['subject'],
        room: json['room'],
        department: json['department'],
        position: json['position'],
        branchId: json['branchId'],
        faceProfileId: json['faceProfileId'],
        boundDeviceId: json['boundDeviceId'],
        photoUrl: json['photoUrl'],
        email: json['email'],
        createdAt: DateTime.parse(json['createdAt']),
        createdByAdmin: json['createdByAdmin'] ?? false,
      );
}
