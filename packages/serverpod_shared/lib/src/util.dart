import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:super_string/super_string.dart';

final Random _random = Random.secure();

/// Generates a secure random string of the specified length.
///
/// The resulting String is `base64` encoded and capped at [length],
/// and thus has a lower entropy than [length] bytes.
String generateRandomString([int length = 32]) {
  var values = List<int>.generate(length, (int i) => _random.nextInt(256));
  return base64Url.encode(values).substring(0, length);
}

/// Generates a list of secure random bytes of the specified length.
Uint8List generateRandomBytes(final int length) {
  return Uint8List.fromList(
    List<int>.generate(length, (final int i) => _random.nextInt(256)),
  );
}

/// Checks whether the 2 given lists contain the same data.
bool uint8ListAreEqual(final Uint8List a, final Uint8List b) {
  if (a.length != b.length) {
    return false;
  }

  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }

  return true;
}

/// Splits at spaces and joins to lowerCamelCase.
String databaseTypeToLowerCamelCase(String databaseType) {
  return databaseType.split(' ').fold('', (previousValue, element) {
    if (previousValue.isEmpty || element.isEmpty) {
      return '$previousValue${element.toLowerCase()}';
    } else {
      return '$previousValue${element.capitalize()}';
    }
  });
}

/// Deterministically truncates an [identifier] to a [maxLength] String.
///
/// If the identifier is longer than the maximum length, the identifier is
/// truncated and [hashLength] number of characters are replaced at the
/// end of the identifier with and identifier digest.
///
/// The hash length cannot be longer than the length of the hash returned
/// from the hash algorithm.
/// The function will silently use the generated hash length if it is shorter
/// than the requested [hashLength].
String truncateIdentifier(
  String identifier,
  int maxLength, {
  int hashLength = 4,
}) {
  if (identifier.length <= maxLength) {
    return identifier;
  }

  if (hashLength > maxLength) {
    throw ArgumentError(
      'Hash length cannot be longer than max length of identifier.',
    );
  }
  var hash = sha256.convert(utf8.encode(identifier)).toString();

  if (hashLength > hash.length) {
    hashLength = hash.length;
  }

  var digest = hash.substring(0, hashLength);

  return identifier.substring(0, maxLength - hashLength) + digest;
}

/// Truncates a column query alias while preserving the column name to avoid
/// collisions in deserialization.
///
/// If the full alias exceeds [maxLength], this function:
/// 1. Preserves the column name at the end
/// 2. Truncates and hashes only the prefix portion
/// 3. Recombines them as "hashedPrefix_columnName"
///
/// This ensures unique, collision-free aliases even with deep nested includes.
String truncateColumnQueryAlias(
  String prefix,
  String columnName,
  int maxLength, {
  int hashLength = 8,
}) {
  var fullAlias = '$prefix.$columnName';

  if (fullAlias.length <= maxLength) {
    return fullAlias;
  }

  // If column name alone is too long, truncate the full alias normally
  if (columnName.length >= maxLength) {
    return truncateIdentifier(fullAlias, maxLength, hashLength: hashLength);
  }

  // Calculate space available for prefix (including separator and hash)
  var availableForPrefix = maxLength - columnName.length - 1; // -1 for underscore separator

  if (availableForPrefix <= hashLength) {
    // Not enough space, use full hash for prefix
    var hash = sha256.convert(utf8.encode(prefix)).toString();
    var prefixDigest = hash.substring(0, min(hashLength, availableForPrefix));
    return '${prefixDigest}_$columnName';
  }

  // Truncate prefix with hash and combine with column name
  var hash = sha256.convert(utf8.encode(prefix)).toString();
  var digest = hash.substring(0, hashLength);
  var truncatedPrefix = prefix.substring(0, availableForPrefix - hashLength) + digest;

  return '${truncatedPrefix}_$columnName';
}
