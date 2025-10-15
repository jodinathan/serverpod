import 'package:serverpod/serverpod.dart';

/// PostgreSQL unaccent extension for ColumnString.
extension ColumnStringUnaccentPgSqlExtension on ColumnString {
  /// Creates an [Expression] for accent-insensitive ILIKE comparison.
  ///
  /// Example:
  /// ```dart
  /// await Clinic.db.find(
  ///   session,
  ///   where: (t) => t.name.unaccentIlike('%clinicao%'),
  /// );
  /// ```
  Expression unaccentIlike(String value) {
    return UnaccentILikeExpression(this, value);
  }
}

/// Expression for accent-insensitive case-insensitive LIKE comparison.
///
/// This class generates SQL for PostgreSQL's unaccent + ILIKE comparison.
class UnaccentILikeExpression extends Expression {
  /// The column to compare.
  final ColumnString column;

  /// The value to compare against.
  final String value;

  /// Creates a new [UnaccentILikeExpression].
  UnaccentILikeExpression(this.column, this.value) : super('');

  @override
  String toString() {
    final columnName = column.toString();
    final escapedValue = value.replaceAll("'", "''");
    return "unaccent_lower($columnName) ILIKE unaccent_lower('$escapedValue')";
  }

  @override
  List<Column> get columns => [column];
}

/// Extension on [Session] to setup PostgreSQL unaccent functionality.
extension UnaccentILikeSession on Session {
  /// Setup PostgreSQL extensions and functions required for unaccent queries.
  ///
  /// Call this once during database initialization:
  /// ```dart
  /// await session.setupUnaccent();
  /// ```
  Future<void> setupUnaccent() async {
    // Execute cada comando separadamente para evitar erro de múltiplos comandos
    await db.unsafeExecute('CREATE EXTENSION IF NOT EXISTS unaccent');
    await db.unsafeExecute('CREATE EXTENSION IF NOT EXISTS pg_trgm');
    await db.unsafeExecute('''
      CREATE OR REPLACE FUNCTION unaccent_lower(text) RETURNS text AS \$\$
      SELECT lower(unaccent(\$1));
      \$\$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE
    ''');
  }
}
