import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Utilidades para el hash del PIN de la casa.
class PinHasher {
  PinHasher._();

  /// Devuelve el hash SHA-256 del PIN (con salt fijo por dispositivo).
  static String hash(String pin, {String salt = ''}) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  /// Verifica que [pin] corresponde al [hash] guardado.
  static bool verify(String pin, String hash, {String salt = ''}) {
    return hashOf(pin, salt: salt) == hash;
  }

  static String hashOf(String pin, {String salt = ''}) => hash(pin, salt: salt);
}
