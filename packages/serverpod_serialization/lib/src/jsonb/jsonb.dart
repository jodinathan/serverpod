import 'dart:convert';

/// Represents a PostgreSQL JSONB (binary JSON) column value.
///
/// JSONB provides better performance and indexing capabilities compared to JSON.
/// Use this type when you need to store semi-structured data with efficient queries.
///
/// Example:
/// ```dart
/// final metadata = Jsonb({'color': 'blue', 'size': 'large', 'weight': 150});
/// ```
class Jsonb {
  /// The underlying JSON data as a Map
  final Map<String, dynamic> data;

  /// Creates a new Jsonb instance from a Map
  const Jsonb(this.data);

  /// Creates a Jsonb from a JSON string or Map
  factory Jsonb.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) return Jsonb(json);
    if (json is String) return Jsonb(jsonDecode(json) as Map<String, dynamic>);
    throw ArgumentError('Jsonb.fromJson expects String or Map<String, dynamic>');
  }

  /// Converts to JSON string
  String toJson() => jsonEncode(data);

  /// Converts to JSON for protocol (returns Map, not String)
  Map<String, dynamic> toJsonForProtocol() => data;

  /// Returns a copy of this Jsonb (shallow copy)
  Jsonb copyWith() => Jsonb(Map<String, dynamic>.from(data));

  /// Access value by key (shorthand for data[key])
  dynamic operator [](String key) => data[key];

  /// Set value by key (shorthand for data[key] = value)
  void operator []=(String key, dynamic value) => data[key] = value;

  /// Check if key exists
  bool containsKey(String key) => data.containsKey(key);

  /// Get all keys
  Iterable<String> get keys => data.keys;

  /// Get all values
  Iterable<dynamic> get values => data.values;

  @override
  String toString() => 'Jsonb($data)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Jsonb &&
          runtimeType == other.runtimeType &&
          _mapsEqual(data, other.data);

  @override
  int get hashCode => data.hashCode;

  static bool _mapsEqual(Map a, Map b) {
    if (a.length != b.length) return false;
    for (var key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
