import '../core/api_client.dart';

/// The person signed in.
class AppUser {
  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.role,
    required this.needsName,
  });

  factory AppUser.fromJson(Json json) {
    return AppUser(
      // Every ID is kept as text: the server's IDs will stop being numbers.
      id: '${json['user_id']}',
      firstName: (json['first_name'] as String?)?.trim() ?? '',
      lastName: (json['last_name'] as String?)?.trim() ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? '',
      needsName: json['needs_name'] == true,
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String role;

  /// True until the person has entered their name, right after first sign-in.
  final bool needsName;

  bool get isCaretaker => role == 'caretaker';

  String get fullName => [firstName, lastName].where((part) => part.isNotEmpty).join(' ');
}
