import 'responder_role.dart';

/// The person using this device.
class Responder {
  const Responder({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.signedInAt,
    this.isOfflineDemo = false,
  });

  final String id;
  final String email;
  final String fullName;
  final ResponderRole role;
  final DateTime signedInAt;

  /// True when the session was created locally without contacting the backend.
  final bool isOfflineDemo;

  Responder copyWith({ResponderRole? role}) => Responder(
        id: id,
        email: email,
        fullName: fullName,
        role: role ?? this.role,
        signedInAt: signedInAt,
        isOfflineDemo: isOfflineDemo,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Responder &&
          other.id == id &&
          other.email == email &&
          other.fullName == fullName &&
          other.role == role &&
          other.isOfflineDemo == isOfflineDemo;

  @override
  int get hashCode => Object.hash(id, email, fullName, role, isOfflineDemo);
}
