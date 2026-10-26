import 'dart:convert';
import 'package:http/http.dart' as http;

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class Api {
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000/api',
  );
  final http.Client _client;
  Api({http.Client? client}) : _client = client ?? http.Client();
  String? token;
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Json? body,
  }) async {
    try {
      final req = http.Request(method, Uri.parse('$baseUrl/$path'));
      req.headers.addAll({
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      if (body != null) req.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 15)),
      );
      final data = response.body.isEmpty ? null : jsonDecode(response.body);
      if (response.statusCode >= 400) {
        final message = data is Map ? data['message'] : null;
        throw ApiException(
          message is List
              ? message.join('\n')
              : message?.toString() ?? 'No se pudo completar la operación.',
        );
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'No se pudo conectar con la barbería. Revisa tu conexión e inténtalo de nuevo.',
      );
    }
  }

  void dispose() => _client.close();
}

/// La zona comercial se muestra siempre como UTC-5, independientemente del dispositivo.
DateTime shopDate(String iso) =>
    DateTime.parse(iso).toUtc().subtract(const Duration(hours: 5));
String timeLabel(String iso) {
  final d = shopDate(iso);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String dayLabel(String iso) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final d = shopDate(iso);
  return '${d.day} ${months[d.month - 1]}';
}

String money(num cents) => '\$${(cents / 100).toStringAsFixed(2)}';
