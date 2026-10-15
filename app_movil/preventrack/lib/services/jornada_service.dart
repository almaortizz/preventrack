import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';
import 'ubicacion_service.dart';

// Resultado de registrar un momento de la jornada
enum ResultadoJornada { registrado, enCola, error }

// Jornada laboral del usuario que inició sesión, con soporte sin conexión:
// guarda en el celular la última jornada que respondió la API y le aplica lo
// que esté en la cola (inicio, comida, fin) mientras no se sincroniza.
class JornadaService {
  static final ApiService _api = ApiService();
  static const _claveLocal = 'jornada_actual';

  // true si la última carga no pudo hablar con la API
  static bool sinConexion = false;
  // Mensaje de la API cuando rechaza un registro (p. ej. orden incorrecto)
  static String? ultimoError;

  /// Jornada abierta del usuario (null si no tiene). Puede traer
  /// 'pendiente_sync' = true si incluye registros que aún no se suben.
  static Future<Map<String, dynamic>?> obtenerActual() async {
    if (DatabaseService.isAvailable &&
        await DatabaseService.contarOperacionesPendientes() > 0) {
      await SyncService.subirPendientes();
    }

    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? jornada;
    try {
      final result = await _api.get('jornadas/actual');
      if (result['statusCode'] != 200) throw Exception('sin datos');
      jornada = result['data']['jornada'] as Map<String, dynamic>?;
      // Respaldo con lo que dice la API (sin lo que está en la cola)
      await prefs.setString(_claveLocal, jsonEncode(jornada));
      sinConexion = false;
    } catch (_) {
      final guardada = prefs.getString(_claveLocal);
      jornada = guardada != null
          ? jsonDecode(guardada) as Map<String, dynamic>?
          : null;
      sinConexion = true;
    }

    return _aplicarPendientes(jornada);
  }

  /// true si hay una jornada iniciada y sin finalizar
  static Future<bool> tieneJornadaActiva() async {
    final jornada = await obtenerActual();
    // Sin conexión y sin nada guardado no se puede saber: no se bloquea
    // (como antes)
    if (jornada == null && sinConexion) return true;
    return jornada != null &&
        jornada['hora_inicio'] != null &&
        jornada['hora_fin'] == null;
  }

  /// Registra iniciar, iniciar_comida, finalizar_comida o finalizar con la
  /// hora real; sin conexión lo guarda en la cola.
  static Future<ResultadoJornada> registrar(String evento) async {
    ultimoError = null;
    final ahora = DateTime.now();

    // Ubicación al iniciar y al finalizar (si no hay GPS, se registra sin ella)
    final conGps = evento == 'iniciar' || evento == 'finalizar';
    final posicion = conGps
        ? await UbicacionService.instancia.obtenerUbicacionActual()
        : null;

    final body = <String, dynamic>{
      'evento': evento,
      'latitud': posicion?.latitude,
      'longitud': posicion?.longitude,
      'fecha_hora_registro': ahora.toUtc().toIso8601String(),
      // Solo lo usa la app para mostrar la hora mientras está en la cola
      'hora_local': ahora.toIso8601String(),
    };

    try {
      final result = await _api.post('jornadas/registrar', body: body);
      if (result['statusCode'] == 200 || result['statusCode'] == 201) {
        return ResultadoJornada.registrado;
      }
      ultimoError =
          (result['data'] is Map ? result['data']['message'] : null) ??
          'No se pudo registrar';
      return ResultadoJornada.error;
    } catch (_) {
      if (!DatabaseService.isAvailable) {
        ultimoError = 'Error de conexión';
        return ResultadoJornada.error;
      }
      await DatabaseService.guardarOperacionPendiente(
        tipo: 'jornada',
        endpoint: 'jornadas/registrar',
        metodo: 'POST',
        body: body,
      );
      return ResultadoJornada.enCola;
    }
  }

  // Aplica en orden los registros de la cola sobre la jornada
  static Future<Map<String, dynamic>?> _aplicarPendientes(
    Map<String, dynamic>? jornada,
  ) async {
    if (!DatabaseService.isAvailable) return jornada;

    var actual = jornada != null ? Map<String, dynamic>.from(jornada) : null;
    for (final op in await DatabaseService.obtenerOperacionesPendientes()) {
      if (op['tipo'] != 'jornada') continue;
      final bodyStr = op['body'] as String?;
      if (bodyStr == null) continue;
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final hora = body['hora_local'];

      switch (body['evento']) {
        case 'iniciar':
          actual = {
            'fecha': (hora as String).substring(0, 10),
            'hora_inicio': hora,
            'hora_inicio_comida': null,
            'hora_fin_comida': null,
            'hora_fin': null,
          };
        case 'iniciar_comida':
          actual?['hora_inicio_comida'] = hora;
        case 'finalizar_comida':
          actual?['hora_fin_comida'] = hora;
        case 'finalizar':
          actual?['hora_fin'] = hora;
      }
      actual?['pendiente_sync'] = true;
    }
    return actual;
  }
}
