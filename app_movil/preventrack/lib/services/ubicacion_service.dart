import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

// Servicio global (singleton) que reporta la ubicación GPS del
// preventista/repartidor al backend cada 90 segundos mientras su
// jornada esté activa.
//
// A diferencia de un temporizador dentro de una pantalla (que se
// cancela en cuanto el usuario navega a otra pantalla y esa pantalla
// se destruye), este servicio vive independiente de cualquier widget,
// así que el reporte de ubicación sigue funcionando aunque la persona
// esté usando Clientes, Pedidos, Entregas, etc. — mientras la app
// siga abierta.
class UbicacionService {
  UbicacionService._interno();
  static final UbicacionService instancia = UbicacionService._interno();

  final ApiService _api = ApiService();
  Timer? _timer;

  bool get activo => _timer != null;

  // Pide el permiso de ubicación si hace falta y devuelve la posición
  // actual del celular. Si el GPS está apagado o el permiso fue
  // negado, regresa null en vez de lanzar un error.
  Future<Position?> obtenerUbicacionActual() async {
    try {
      final servicioActivo = await Geolocator.isLocationServiceEnabled();
      if (!servicioActivo) return null;

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _reportarUbicacion() async {
    final position = await obtenerUbicacionActual();
    if (position == null) return;
    try {
      await _api.post(
        'ubicacion',
        body: {
          'latitud': position.latitude,
          'longitud': position.longitude,
        },
      );
    } catch (_) {
      // Si falla, se intenta de nuevo en el siguiente ciclo.
    }
  }

  // Inicia el reporte periódico. Si ya estaba activo, no hace nada
  // (evita duplicar temporizadores).
  void iniciar() {
    if (_timer != null) return;
    _reportarUbicacion(); // primer reporte inmediato
    _timer = Timer.periodic(const Duration(seconds: 90), (_) {
      _reportarUbicacion();
    });
  }

  void detener() {
    _timer?.cancel();
    _timer = null;
  }
}
