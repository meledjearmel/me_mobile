import 'package:flutter/foundation.dart';

/// Statut d'un message de contact (§3.6). `newMessage` évite le mot réservé `new`.
enum ContactStatus {
  newMessage('new', 'Nouveau'),
  read('read', 'Lu'),
  replied('replied', 'Répondu');

  const ContactStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ContactStatus fromWire(String? value) =>
      values.firstWhere((s) => s.wireValue == value, orElse: () => ContactStatus.newMessage);
}

/// Message du formulaire de contact du site public (§4.2).
@immutable
class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.email,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        subject: json['subject'] as String?,
        message: json['message'] as String,
        status: ContactStatus.fromWire(json['status'] as String?),
        createdAt: json['created_at'] == null ? null : DateTime.parse(json['created_at'] as String),
      );

  final int id;
  final String name;
  final String email;
  final String? subject;
  final String message;
  final ContactStatus status;
  final DateTime? createdAt;

  Contact copyWith({ContactStatus? status}) => Contact(
        id: id,
        name: name,
        email: email,
        subject: subject,
        message: message,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
