import 'dart:convert';

import 'package:shelf/shelf.dart';

Response jsonResponse(Object? body, {int status = 200}) => Response(
      status,
      body: json.encode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Response jsonError(String message, {int status = 400}) => jsonResponse({'error': message}, status: status);

Future<Map<String, dynamic>> readJsonBody(Request request) async {
  final body = await request.readAsString();
  if (body.isEmpty) return {};
  final decoded = json.decode(body);
  return decoded is Map<String, dynamic> ? decoded : {};
}
