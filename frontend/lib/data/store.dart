import 'package:flutter/foundation.dart';
import 'api.dart';

class Store extends ChangeNotifier {
  final Api api;
  Store({Api? api}) : api = api ?? Api();
  bool authRequested = false, pendingReservation = false;
  String? pendingServiceId;
  Json shop = {};
  Json? user;
  String? accountNotice;
  bool demo = false;
  List<Json> services = [], barbers = [], appointments = [];
  Json card = {'currentStamps': 0, 'events': []};
  bool get staff => user != null && user!['role'] != 'CLIENT';
  bool get admin => user?['role'] == 'ADMIN';

  Future<void> refreshIdentity() async {
    if (demo || user == null) return;
    user = Json.from(await api.request('auth/me'));
    notifyListeners();
  }

  void requestLogin({bool booking = false, Json? service}) {
    pendingReservation = booking;
    pendingServiceId = service?['id'];
    authRequested = true;
    notifyListeners();
  }

  void cancelLogin() {
    authRequested = false;
    pendingReservation = false;
    pendingServiceId = null;
    notifyListeners();
  }

  Future<void> loadPublic() async {
    final result = await Future.wait([
      api.request('shop'),
      api.request('services'),
      api.request('users/barbers'),
    ]);
    if (user != null || demo) return;
    shop = Json.from(result[0]);
    services = (result[1] as List).map((e) => Json.from(e)).toList();
    barbers = (result[2] as List).map((e) => Json.from(e)).toList();
    notifyListeners();
  }

  Future<void> login(String email, String password, {String? name}) async {
    final data = await api.request(
      name == null ? 'auth/login' : 'auth/register',
      method: 'POST',
      body: {
        'email': email.trim(),
        'password': password,
        if (name != null) 'name': name.trim(),
      },
    );
    api.token = data['accessToken'];
    user = Json.from(data['user']);
    accountNotice = name == null
        ? null
        : data['verificationEmailSent'] == true
        ? 'Te enviamos un enlace para verificar tu correo.'
        : 'Tu cuenta está creada, pero no pudimos enviar el correo. Puedes reintentarlo en Mi cuenta.';
    demo = false;
    notifyListeners();
  }

  void enterDemo({bool asStaff = false}) {
    demo = true;
    user = {
      'id': 'demo-client',
      'name': asStaff ? 'Mateo Rivera' : 'Alex Moreno',
      'email': asStaff ? 'mateo@ejemplo.com' : 'alex@ejemplo.com',
      'role': asStaff ? 'BARBER' : 'CLIENT',
    };
    services = [
      {
        'id': 'cut',
        'name': 'Corte clásico',
        'description': 'Tu estilo de siempre, con un acabado impecable.',
        'durationMin': 30,
        'priceCents': 1200,
        'rewardEligible': true,
      },
      {
        'id': 'beard',
        'name': 'Diseño de barba',
        'description': 'Perfilado, definición y cuidado en cada detalle.',
        'durationMin': 30,
        'priceCents': 800,
        'rewardEligible': false,
      },
      {
        'id': 'combo',
        'name': 'Corte + barba',
        'description': 'La experiencia completa para renovar tu look.',
        'durationMin': 60,
        'priceCents': 1800,
        'rewardEligible': false,
      },
    ];
    barbers = [
      {'id': 'mateo', 'name': 'Mateo Rivera'},
      {'id': 'lucas', 'name': 'Lucas Torres'},
    ];
    final date = DateTime.now().toUtc().add(const Duration(days: 1));
    final start = DateTime.utc(date.year, date.month, date.day, 15);
    appointments = [
      {
        'id': 'demo-appointment',
        'startsAt': start.toIso8601String(),
        'endsAt': start.add(const Duration(minutes: 30)).toIso8601String(),
        'service': services[0],
        'barber': barbers[0],
        'client': {'id': 'demo-client', 'name': 'Alex Moreno'},
        'status': 'PENDING',
        'priceCents': 1200,
        'isReward': false,
      },
    ];
    card = {'currentStamps': 7, 'lifetimeStamps': 7, 'events': []};
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!demo) {
      final result = await Future.wait([
        api.request(admin ? 'services/manage' : 'services'),
        api.request('users/barbers'),
        api.request('appointments'),
        if (!staff) api.request('stamps/card'),
        api.request('shop'),
        api.request('auth/me'),
      ]);
      services = (result[0] as List).map((e) => Json.from(e)).toList();
      barbers = (result[1] as List).map((e) => Json.from(e)).toList();
      appointments = (result[2] as List).map((e) => Json.from(e)).toList();
      if (!staff) card = Json.from(result[3]);
      shop = Json.from(result[result.length - 2]);
      user = Json.from(result.last);
    }
    notifyListeners();
  }

  Future<List<String>> slots(
    String barberId,
    String serviceId,
    DateTime day,
  ) async {
    if (demo) {
      if (day.weekday == DateTime.sunday) return [];
      final duration =
          services.firstWhere((s) => s['id'] == serviceId)['durationMin']
              as int;
      final closing = DateTime.utc(day.year, day.month, day.day + 1);
      return List.generate(
            20,
            (i) => DateTime.utc(
              day.year,
              day.month,
              day.day,
              14,
            ).add(Duration(minutes: i * 30)),
          )
          .where(
            (d) =>
                d.isAfter(DateTime.now().toUtc()) &&
                !d.add(Duration(minutes: duration)).isAfter(closing) &&
                !appointments.any(
                  (a) =>
                      a['status'] != 'CANCELLED' &&
                      d.isBefore(DateTime.parse(a['endsAt'])) &&
                      d
                          .add(Duration(minutes: duration))
                          .isAfter(DateTime.parse(a['startsAt'])),
                ),
          )
          .map((d) => d.toIso8601String())
          .toList();
    }
    final date =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final result = await api.request(
      'appointments/availability?barberId=$barberId&serviceId=$serviceId&date=$date',
    );
    return List<String>.from(result['slots']);
  }

  Future<void> book(
    Json service,
    Json barber,
    String start,
    bool reward,
  ) async {
    if (demo) {
      appointments.insert(0, {
        'id': 'demo-${DateTime.now().microsecondsSinceEpoch}',
        'startsAt': start,
        'endsAt': DateTime.parse(
          start,
        ).add(Duration(minutes: service['durationMin'])).toIso8601String(),
        'service': service,
        'barber': barber,
        'client': {'name': user!['name']},
        'status': 'PENDING',
        'priceCents': reward ? 0 : service['priceCents'],
        'isReward': reward,
      });
    } else {
      await api.request(
        'appointments',
        method: 'POST',
        body: {
          'serviceId': service['id'],
          'barberId': barber['id'],
          'startsAt': start,
          'isReward': reward,
        },
      );
    }
    await refresh();
  }

  Future<void> cancel(Json appointment) async {
    if (demo) {
      appointment['status'] = 'CANCELLED';
    } else {
      await api.request(
        'appointments/${appointment['id']}/cancel',
        method: 'PATCH',
      );
    }
    await refresh();
  }

  Future<String> qr() async => demo
      ? 'BARBERIA-DEMO-SIN-VALOR'
      : (await api.request('stamps/qr'))['qrToken'];

  Future<void> accept(Json appointment) async {
    if (demo) {
      appointment['acceptedAt'] = DateTime.now().toUtc().toIso8601String();
    } else {
      await api.request(
        'appointments/${appointment['id']}/accept',
        method: 'PATCH',
      );
    }
    await refresh();
  }

  Future<void> saveService(Json data, {String? id}) async {
    await api.request(
      id == null ? 'services' : 'services/$id',
      method: id == null ? 'POST' : 'PATCH',
      body: data,
    );
    await refresh();
  }

  Future<void> createBarber(Json data) async {
    await api.request('users/barbers', method: 'POST', body: data);
    await refresh();
  }

  Future<Json> scan(String token) async {
    if (demo) {
      if (token != 'BARBERIA-DEMO-SIN-VALOR') {
        throw ApiException(
          'En demostración usa el código BARBERIA-DEMO-SIN-VALOR.',
        );
      }
      return {
        'client': {'name': 'Alex Moreno'},
        'currentStamps': card['currentStamps'],
        'appointments': appointments
            .where((a) => a['status'] == 'PENDING')
            .toList(),
      };
    }
    return Json.from(
      await api.request(
        'stamps/scan',
        method: 'POST',
        body: {'qrToken': token},
      ),
    );
  }

  Future<void> complete(String token, String appointmentId) async {
    if (demo) {
      appointments.firstWhere((a) => a['id'] == appointmentId)['status'] =
          'COMPLETED';
      card['currentStamps'] = ((card['currentStamps'] as int) + 1).clamp(0, 10);
    } else {
      await api.request(
        'stamps/complete',
        method: 'POST',
        body: {'qrToken': token, 'appointmentId': appointmentId},
      );
    }
    await refresh();
  }

  void logout() {
    authRequested = false;
    pendingReservation = false;
    pendingServiceId = null;
    user = null;
    accountNotice = null;
    api.token = null;
    services = [];
    barbers = [];
    appointments = [];
    card = {'currentStamps': 0, 'events': []};
    demo = false;
    notifyListeners();
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }
}
