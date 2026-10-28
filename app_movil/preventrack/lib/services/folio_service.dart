import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

// Folio del pedido generado en el celular, con el esquema "serie y folio":
// P{id del preventista}-{AA}-{consecutivo}, p. ej. P2-26-0153.
// - La serie (id del usuario) evita que dos preventistas repitan números,
//   aunque trabajen sin conexión al mismo tiempo.
// - El consecutivo es por año y continúa desde el mayor entre lo guardado en
//   el celular y lo que dice la API (por si cambió de celular o reinstaló).
// - La API rechaza folios repetidos (columna única) y reconoce reintentos.
class FolioService {
  static final ApiService _api = ApiService();

  static String _clave(int usuarioId, int anio) => 'folio_${usuarioId}_$anio';

  static int _anio(DateTime fecha) => fecha.year % 100;

  /// Siguiente folio del usuario. Se guarda de inmediato para no repetirlo
  /// aunque el pedido falle (un hueco en la numeración es aceptable).
  static Future<String> siguiente(int usuarioId) async {
    final anio = _anio(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final clave = _clave(usuarioId, anio);

    final consecutivo = (prefs.getInt(clave) ?? 0) + 1;
    await prefs.setInt(clave, consecutivo);

    return 'P$usuarioId-${anio.toString().padLeft(2, '0')}-'
        '${consecutivo.toString().padLeft(4, '0')}';
  }

  /// Toma de la API el último consecutivo del año y se queda con el mayor.
  /// Si no hay conexión no pasa nada: se intenta en la siguiente ocasión.
  static Future<void> actualizarDesdeApi() async {
    try {
      final result = await _api.get('ventas/ultimo-folio');
      if (result['statusCode'] != 200) return;

      final data = result['data'];
      final usuarioId = int.tryParse(data['usuario_id'].toString());
      final anio = int.tryParse(data['anio'].toString());
      final delServidor = int.tryParse(data['consecutivo'].toString()) ?? 0;
      if (usuarioId == null || anio == null) return;

      final prefs = await SharedPreferences.getInstance();
      final clave = _clave(usuarioId, anio);
      if (delServidor > (prefs.getInt(clave) ?? 0)) {
        await prefs.setInt(clave, delServidor);
      }
    } catch (_) {}
  }
}
