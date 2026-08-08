import 'dart:convert';

import 'package:crypto/crypto.dart';

class JwtException implements Exception {
  final String message;
  JwtException(this.message);
  @override
  String toString() => message;
}

/// Node 백엔드가 쓰는 `jsonwebtoken`과 호환되는 최소한의 HS256 JWT 구현
/// (헤더.페이로드.서명, base64url, HMAC-SHA256). 두 백엔드가 같은
/// JWT_SECRET을 쓰면 서로 발급한 토큰을 그대로 검증할 수 있다.
class Jwt {
  static String _b64UrlEncode(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

  static List<int> _b64UrlDecode(String s) {
    final padded = s + '=' * ((4 - s.length % 4) % 4);
    return base64Url.decode(padded);
  }

  static String sign(
    Map<String, dynamic> payload,
    String secret, {
    Duration expiresIn = const Duration(days: 30),
  }) {
    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final now = DateTime.now().toUtc();
    final fullPayload = {
      ...payload,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': now.add(expiresIn).millisecondsSinceEpoch ~/ 1000,
    };
    final headerSeg = _b64UrlEncode(utf8.encode(json.encode(header)));
    final payloadSeg = _b64UrlEncode(utf8.encode(json.encode(fullPayload)));
    final signingInput = '$headerSeg.$payloadSeg';
    final signature = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(signingInput));
    return '$signingInput.${_b64UrlEncode(signature.bytes)}';
  }

  /// 서명과 만료시간을 검증하고 페이로드를 반환한다. 유효하지 않으면 [JwtException]을 던진다.
  static Map<String, dynamic> verify(String token, String secret) {
    final parts = token.split('.');
    if (parts.length != 3) throw JwtException('잘못된 토큰 형식입니다.');

    final signingInput = '${parts[0]}.${parts[1]}';
    final expectedSig = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(signingInput));
    if (!_constantTimeEquals(_b64UrlEncode(expectedSig.bytes), parts[2])) {
      throw JwtException('유효하지 않은 토큰입니다.');
    }

    final payload = json.decode(utf8.decode(_b64UrlDecode(parts[1]))) as Map<String, dynamic>;
    final exp = payload['exp'];
    if (exp is int) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      if (DateTime.now().toUtc().isAfter(expiry)) throw JwtException('토큰이 만료되었습니다.');
    }
    return payload;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
