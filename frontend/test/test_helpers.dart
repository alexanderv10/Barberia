import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:barberia/data/api.dart';
import 'package:barberia/data/store.dart';

Store testStore({List<String>? requests, bool unavailable = false}) => Store(
  api: Api(
    client: MockClient((request) async {
      final path = request.url.path.replaceFirst('/api/', '');
      requests?.add(path);
      if (unavailable) return http.Response('{"message":"Sin conexión"}', 503);
      final public = {
        'shop': {
          'name': 'Barbería',
          'hours': 'Lunes a sábado · 09:00 a 19:00',
          'address': 'Calle de prueba 123',
          'phone': 'Contacto de prueba',
        },
        'services': [
          {
            'id': 'cut',
            'name': 'Corte clásico',
            'description': 'Corte y acabado',
            'durationMin': 30,
            'priceCents': 1200,
            'rewardEligible': true,
          },
        ],
        'users/barbers': [
          {'id': 'mateo', 'name': 'Mateo Rivera'},
        ],
      };
      if (public.containsKey(path)) {
        return http.Response(jsonEncode(public[path]), 200);
      }
      if (path == 'auth/login' || path == 'auth/register') {
        return http.Response(
          jsonEncode({
            'accessToken': 'test-token',
            'user': {
              'id': 'client',
              'name': 'Alex Moreno',
              'email': 'cliente@ejemplo.com',
              'role': 'CLIENT',
            },
          }),
          201,
        );
      }
      if (request.headers['Authorization'] != 'Bearer test-token') {
        return http.Response('{"message":"Sin sesión"}', 401);
      }
      if (path == 'appointments') return http.Response('[]', 200);
      if (path == 'auth/me') return http.Response('{"id":"client","name":"Alex Moreno","email":"cliente@ejemplo.com","role":"CLIENT","emailVerified":false}', 200);
      if (path == 'auth/email/resend') return http.Response('{"sent":true,"message":"Enviamos un enlace a tu correo."}', 201);
      if (path == 'stamps/card') {
        return http.Response('{"currentStamps":0,"events":[]}', 200);
      }
      if (path == 'appointments/availability') {
        return http.Response('{"slots":[]}', 200);
      }
      return http.Response('{"message":"Ruta inesperada"}', 404);
    }),
  ),
);
