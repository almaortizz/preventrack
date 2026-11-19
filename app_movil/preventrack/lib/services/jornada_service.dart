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
  // Límite de una jornada abierta: al cumplirlo se cierra automáticamente.
  // Único lugar de la app donde se define (en la API:
  // Jornada::HORAS_CIERRE_AUTOMATICO).
  static const horasCierreAutomatico = 17;

  static const mensajeCierreAutomatico =
      'Tu jornada se cerró automáticamente al cumplir '
      '$horasCierreAutomatico horas.';

  static final ApiService _api = ApiService();
  static const _claveLocal = 'jornada_actual';
  static const _claveAvisoCierre = 'aviso_cierre_automatico';

  // true si la última carga no pudo hablar con la API
  static bool sinConexion = false;

  /// Celular compartido: al entrar otro usuario se borra la jornada guardada
  /// del anterior (con conexión se vuelve a consultar la del nuevo).
  static Future<void> borrarDatosLocales() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveLocal);
    await prefs.remove(_claveAvisoCierre);
  }

  // Mensaje de la API cuando rechaza un registro (p. ej. orden incorrecto)
  static String? ultimoError;

  /// Jornada abierta del usuario (null si no tiene). Puede traer
  /// 'pendiente_sync' = true si incluye registros que aún no se suben, y
  /// 'cierre_automatico' = true si el celular la cerró por el límite.
  static Future<Map<String, dynamic>?> obtenerActual() async {
    if (DatabaseService.isAvailable &&
        await DatabaseService.contarOperacionesPendientes() > 0) {
      await SyncService.subirPendientes();
    }

    final prefs = await SharedPreferences.getInstance();
    // Lo guardado antes de consultar: sirve para saber si la API la cerró sola
    final anterior = _decodificar(prefs.getString(_claveLocal));

    Map<String, dynamic>? jornada;
    try {
      final result = await _api.get('jornadas/actual');
      if (result['statusCode'] != 200) throw Exception('sin datos');
      jornada = result['data']['jornada'] as Map<String, dynamic>?;
      // Respaldo con lo que dice la API (sin lo que está en la cola)
      await prefs.setString(_claveLocal, jsonEncode(jornada));
      sinConexion = false;
    } catch (_) {
      jornada = anterior;
      sinConexion = true;
    }

    var resultado = await _aplicarPendientes(jornada);
    // Sin conexión (o si la API aún no la cerró) la cierra el celular
    resultado = await _cerrarSiVencida(resultado);

    // La API ya la cerró por el límite: avisar al preventista una vez
    if (!sinConexion &&
        resultado == null &&
        _abierta(anterior) &&
        _vencida(anterior!)) {
      await _guardarAviso();
    }

    // Sin jornada activa no se envía la ubicación
    if (!_abierta(resultado)) UbicacionService.instancia.detener();

    return resultado;
  }

  /// true si hay una jornada iniciada y sin finalizar
  static Future<bool> tieneJornadaActiva() async {
    final jornada = await obtenerActual();
    // Sin conexión y sin nada guardado no se puede saber: no se bloquea
    // (como antes)
    if (jornada == null && sinConexion) return true;
    return _abierta(jornada);
  }

  /// Revisión solo con lo guardado en el celular (sin consultar la API), para
  /// el envío de ubicación cada 90 s. true si la jornada acaba de cerrarse
  /// por el límite.
  static Future<bool> cerrarSiVencidaSinConexion() async {
    final prefs = await SharedPreferences.getInstance();
    final jornada = await _aplicarPendientes(
      _decodificar(prefs.getString(_claveLocal)),
    );
    if (!_abierta(jornada) || !_vencida(jornada!)) return false;

    await _cerrarSiVencida(jornada);
    return true;
  }

  /// Mensaje de cierre automático pendiente de mostrar (una sola vez)
  static Future<String?> tomarAvisoCierre() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_claveAvisoCierre) != true) return null;
    await prefs.remove(_claveAvisoCierre);
    return mensajeCierreAutomatico;
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

  // ── Cierre automático ──

  static Map<String, dynamic>? _decodificar(String? guardada) =>
      guardada != null ? jsonDecode(guardada) as Map<String, dynamic>? : null;

  static bool _abierta(Map<String, dynamic>? jornada) =>
      jornada != null &&
      jornada['hora_inicio'] != null &&
      jornada['hora_fin'] == null;

  // hora_inicio + el límite (la hora de inicio viene en hora local)
  static DateTime? _limiteCierre(Map<String, dynamic> jornada) {
    final inicio = DateTime.tryParse(jornada['hora_inicio'].toString());
    return inicio?.add(const Duration(hours: horasCierreAutomatico));
  }

  static bool _vencida(Map<String, dynamic> jornada) {
    final limite = _limiteCierre(jornada);
    return limite != null && !DateTime.now().isBefore(limite);
  }

  // Si la jornada sigue abierta y cumplió el límite, la cierra en el celular
  // y deja el cierre en la cola para la API (con la hora de inicio en UTC,
  // para compararla sin problemas de formato ni zona horaria)
  static Future<Map<String, dynamic>?> _cerrarSiVencida(
    Map<String, dynamic>? jornada,
  ) async {
    if (!_abierta(jornada) || !_vencida(jornada!)) return jornada;
    final abierta = jornada;

    final fin = _limiteCierre(abierta)!;
    if (DatabaseService.isAvailable) {
      await DatabaseService.guardarOperacionPendiente(
        tipo: 'jornada',
        endpoint: 'jornadas/registrar',
        metodo: 'POST',
        body: {
          'evento': 'cierre_automatico',
          'hora_inicio_jornada': DateTime.parse(
            abierta['hora_inicio'].toString(),
          ).toUtc().toIso8601String(),
          'hora_fin': fin.toUtc().toIso8601String(),
          'cierre_automatico': true,
          // Solo lo usa la app para mostrarla mientras está en la cola
          'hora_local': fin.toIso8601String(),
        },
      );
    }

    await _guardarAviso();
    UbicacionService.instancia.detener();

    return {
      ..._aplicarCierre(abierta, fin.toIso8601String()),
      'pendiente_sync': true,
    };
  }

  // hora_fin = inicio + límite, sin coordenadas de fin; si estaba en comida,
  // la comida termina al cierre (igual que en la API)
  static Map<String, dynamic> _aplicarCierre(
    Map<String, dynamic> jornada,
    String horaFin,
  ) {
    final cerrada = Map<String, dynamic>.from(jornada);
    cerrada['hora_fin'] = horaFin;
    cerrada['cierre_automatico'] = true;
    cerrada['latitud_fin'] = null;
    cerrada['longitud_fin'] = null;
    if (cerrada['hora_inicio_comida'] != null &&
        cerrada['hora_fin_comida'] == null) {
      cerrada['hora_fin_comida'] = horaFin;
    }
    return cerrada;
  }

  static Future<void> _guardarAviso() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveAvisoCierre, true);
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
        case 'cierre_automatico':
          if (actual != null && actual['hora_fin'] == null) {
            actual = _aplicarCierre(actual, hora as String);
          }
      }
      actual?['pendiente_sync'] = true;
    }
    return actual;
  }
}
