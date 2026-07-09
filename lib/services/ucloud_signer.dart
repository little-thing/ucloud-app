import 'dart:convert';

import 'package:crypto/crypto.dart';

/// UCloud / CompShare API 签名。
///
/// 规则：参数按 key 升序拼接 `key+value`，末尾追加 PrivateKey，再做 SHA1 hex。
class UCloudSigner {
  const UCloudSigner();

  String sign(Map<String, Object?> params, String privateKey) {
    final sortedKeys = params.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final key in sortedKeys) {
      final value = params[key];
      if (value == null) continue;
      buffer.write(key);
      buffer.write(_encodeValue(value));
    }
    buffer.write(privateKey);
    return sha1.convert(utf8.encode(buffer.toString())).toString();
  }

  String _encodeValue(Object value) {
    if (value is bool) return value ? 'true' : 'false';
    if (value is double) {
      if (value == value.roundToDouble()) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    if (value is List) {
      throw ArgumentError('列表参数需在调用前展开为 Key.N 形式');
    }
    return value.toString();
  }
}
