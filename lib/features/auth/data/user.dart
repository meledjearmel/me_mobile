import 'package:flutter/foundation.dart';

/// Administrateur connecté (`UserResource`).
@immutable
class User {
  const User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
      );

  final int id;
  final String name;
  final String email;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  /// « Armel Meledje » → « AM ».
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    final letters = parts.length == 1 ? parts.first.substring(0, 1) : '${parts.first[0]}${parts.last[0]}';
    return letters.toUpperCase();
  }

  @override
  bool operator ==(Object other) => other is User && other.id == id && other.name == name && other.email == email;

  @override
  int get hashCode => Object.hash(id, name, email);
}
