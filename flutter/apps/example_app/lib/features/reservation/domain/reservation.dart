import 'package:flutter/foundation.dart';

/// Reservation domain entity. Pure Dart, no Flutter/SDK deps;
/// the data layer maps DTOs into this.
@immutable
class Reservation {
  const Reservation({
    required this.id,
    required this.title,
  });

  final String id;
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reservation &&
          other.id == id &&
          other.title == title);

  @override
  int get hashCode => Object.hash(id, title);
}
