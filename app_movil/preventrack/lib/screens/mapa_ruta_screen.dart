import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'catalogo_productos_screen.dart';

class MapaRutaScreen extends StatefulWidget {
  const MapaRutaScreen({super.key});

  @override
  State<MapaRutaScreen> createState() => _MapaRutaScreenState();
}

class _MapaRutaScreenState extends State<MapaRutaScreen> {
  final ApiService _api = ApiService();
  final MapController _mapController = MapController();
  Map<String, dynamic>? _ruta;
  List<dynamic> _paradas = [];
  bool _isLoading = true;
  int _visitadas = 0;
  bool _modoOffline = false;

  // GPS y estado de ruta
  bool _rutaIniciada = false;
  LatLng? _ubicacionActual;
  StreamSubscription<Position>? _positionStream;
  DateTime? _horaInicioRuta;
  List<LatLng> _rutaCalles = [];

  @override
  void initState() {
    super.initState();
    _cargarRuta();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _cargarRuta() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.get('ruta-del-dia');
      if (result['statusCode'] == 200) {
        _ruta = result['data']['ruta'];
        if (_ruta != null) {
          _paradas = _ruta!['detalle'] ?? [];
          _paradas.sort(
            (a, b) =>
                (a['orden_visita'] ?? 0).compareTo(b['orden_visita'] ?? 0),
          );
          _visitadas = _paradas.where((p) => p['estado'] == 'visitada').length;
        }
        _modoOffline = false;
        if (DatabaseService.isAvailable) {
          await DatabaseService.guardarRutaDelDia(_ruta);
        }
        setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      // Sin conexión
    }

    if (DatabaseService.isAvailable) {
      final rutaLocal = await DatabaseService.obtenerRutaDelDia();
      if (rutaLocal != null) {
        _ruta = rutaLocal;
        _paradas = _ruta!['detalle'] ?? [];
        _paradas.sort(
          (a, b) => (a['orden_visita'] ?? 0).compareTo(b['orden_visita'] ?? 0),
        );
        _visitadas = _paradas.where((p) => p['estado'] == 'visitada').length;
        _modoOffline = true;
        _cargarRutaOSRM();
      }
    }
    setState(() => _isLoading = false);
    _cargarRutaOSRM();
  }

  Future<void> _cargarRutaOSRM() async {
    final puntos = <LatLng>[];

    for (var parada in _paradas) {
      final domicilio = parada['domicilio'];
      if (domicilio == null) continue;
      final lat = double.tryParse(domicilio['latitud']?.toString() ?? '');
      final lng = double.tryParse(domicilio['longitud']?.toString() ?? '');
      if (lat != null && lng != null) {
        puntos.add(LatLng(lat, lng));
      }
    }

    if (puntos.length < 2) return;

    try {
      final coords = puntos
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson',
      );
      final response = await http.get(url);

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final coordinates =
              routes[0]['geometry']['coordinates'] as List<dynamic>;
          setState(() {
            _rutaCalles = coordinates
                .map(
                  (c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ),
                )
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════
  //  INICIAR / FINALIZAR RUTA
  // ═══════════════════════════════════════════

  Future<void> _iniciarRuta() async {
    if (kIsWeb) {
      setState(() {
        _rutaIniciada = true;
        _horaInicioRuta = DateTime.now();
      });
      return;
    }

    // Verificar permisos GPS
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activa el GPS de tu dispositivo'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de ubicación denegado'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activa el permiso de ubicación en Ajustes'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Obtener ubicación inicial
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;

      setState(() {
        _ubicacionActual = LatLng(position.latitude, position.longitude);
        _rutaIniciada = true;
        _horaInicioRuta = DateTime.now();
      });

      // Centrar mapa en la ubicación actual
      _mapController.move(_ubicacionActual!, 15);

      // Iniciar seguimiento en tiempo real
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10, // Actualizar cada 10 metros
            ),
          ).listen((Position position) {
            if (mounted) {
              setState(() {
                _ubicacionActual = LatLng(
                  position.latitude,
                  position.longitude,
                );
              });
            }
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ruta iniciada — GPS activo'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener la ubicación'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _finalizarRuta() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar ruta'),
        content: Text(
          '¿Estás seguro de finalizar tu ruta?\n'
          'Paradas visitadas: $_visitadas de ${_paradas.length}',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _positionStream?.cancel();
              setState(() {
                _rutaIniciada = false;
                _ubicacionActual = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ruta finalizada'),
                  backgroundColor: AppColors.primary,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  MARCAR VISITADA
  // ═══════════════════════════════════════════

  Future<void> _marcarVisitada(int paradaId, BuildContext sheetContext) async {
    final rutaId = _ruta?['id'];
    if (rutaId == null) return;

    try {
      final result = await _api.post('rutas/$rutaId/visitar/$paradaId');

      if (!mounted) return;

      if (result['statusCode'] == 200) {
        Navigator.pop(sheetContext);
        await _cargarRuta();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parada marcada como visitada'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        final mensaje = result['data']?['message'] ?? 'Error al marcar visita';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _marcarNoDisponible(int paradaId, BuildContext sheetContext) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cliente no disponible'),
        content: const Text(
          'El cliente no se encuentra. ¿Marcar la parada como no disponible?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(sheetContext);

              final rutaId = _ruta?['id'];
              if (rutaId == null) return;

              try {
                await _api.post('rutas/$rutaId/visitar/$paradaId');
                await _cargarRuta();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Parada marcada — cliente no disponible'),
                    backgroundColor: AppColors.warning,
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error de conexión'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sí, marcar'),
          ),
        ],
      ),
    );
  }

  Future<void> _marcarVisitadaAutomatica(int paradaId) async {
    final rutaId = _ruta?['id'];
    if (rutaId == null) return;

    try {
      await _api.post('rutas/$rutaId/visitar/$paradaId');
      await _cargarRuta();
    } catch (_) {}
  }

  // ═══════════════════════════════════════════
  //  MARKERS Y LÍNEAS
  // ═══════════════════════════════════════════

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Punto azul — ubicación actual
    if (_rutaIniciada && _ubicacionActual != null) {
      markers.add(
        Marker(
          point: _ubicacionActual!,
          width: 28,
          height: 28,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Paradas de la ruta
    for (var i = 0; i < _paradas.length; i++) {
      final parada = _paradas[i];
      final domicilio = parada['domicilio'];
      if (domicilio == null) continue;

      final lat = double.tryParse(domicilio['latitud']?.toString() ?? '');
      final lng = double.tryParse(domicilio['longitud']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      final cliente = domicilio['cliente'];
      final nombre = cliente != null
          ? (cliente['nombre_negocio'] ?? 'Cliente')
          : 'Cliente';
      final direccion = domicilio['direccion'] ?? '';
      final estado = parada['estado'] ?? 'pendiente';
      final orden = parada['orden_visita'] ?? (i + 1);
      final paradaId = parada['id'];

      final esVisitada = estado == 'visitada';
      final color = esVisitada ? AppColors.success : AppColors.warning;

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () =>
                _mostrarInfoParada(nombre, direccion, estado, orden, paradaId),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: esVisitada
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Text(
                        '$orden',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  List<Polyline> _buildRutaLinea() {
    final puntos = <LatLng>[];

    for (var parada in _paradas) {
      final domicilio = parada['domicilio'];
      if (domicilio == null) continue;
      final lat = double.tryParse(domicilio['latitud']?.toString() ?? '');
      final lng = double.tryParse(domicilio['longitud']?.toString() ?? '');
      if (lat != null && lng != null) {
        puntos.add(LatLng(lat, lng));
      }
    }

    if (puntos.length < 2) return [];

    return [
      Polyline(
        points: puntos,
        strokeWidth: 3,
        color: AppColors.primary.withValues(alpha: 0.6),
      ),
    ];
  }

  // ═══════════════════════════════════════════
  //  BOTTOM SHEET — INFO DE PARADA
  // ═══════════════════════════════════════════

  void _mostrarInfoParada(
    String nombre,
    String direccion,
    String estado,
    int orden,
    int paradaId,
  ) {
    final esVisitada = estado == 'visitada';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: esVisitada
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: esVisitada
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 24,
                          )
                        : Text(
                            '$orden',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: esVisitada
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          esVisitada
                              ? 'Visitada'
                              : 'Pendiente — Parada #$orden',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: esVisitada
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (direccion.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.textPrimary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      direccion,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Botones solo si la parada está pendiente
            if (!esVisitada) ...[
              const SizedBox(height: 16),
              // Nuevo Pedido
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    final parada = _paradas.firstWhere(
                      (p) => p['id'] == paradaId,
                      orElse: () => {},
                    );
                    if (parada.isNotEmpty) {
                      final domicilio = parada['domicilio'];
                      final cliente = domicilio?['cliente'];
                      if (cliente != null) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CatalogoProductosScreen(cliente: cliente),
                          ),
                        );
                        // Auto-marcar como visitada al regresar
                        await _marcarVisitadaAutomatica(paradaId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Parada marcada como visitada'),
                              backgroundColor: AppColors.success,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                  label: const Text(
                    'Nuevo Pedido',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Marcar visitada (sin pedido)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => _marcarVisitada(paradaId, sheetContext),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text(
                    'Marcar visitada (sin pedido)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Cliente no disponible
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => _marcarNoDisponible(paradaId, sheetContext),
                  icon: const Icon(Icons.person_off_outlined, size: 20),
                  label: const Text(
                    'Cliente no disponible',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  LatLng _getCentro() {
    // Si la ruta está activa y tenemos ubicación, centrar ahí
    if (_rutaIniciada && _ubicacionActual != null) {
      return _ubicacionActual!;
    }

    double latSum = 0, lngSum = 0;
    int count = 0;

    for (var parada in _paradas) {
      final domicilio = parada['domicilio'];
      if (domicilio == null) continue;
      final lat = double.tryParse(domicilio['latitud']?.toString() ?? '');
      final lng = double.tryParse(domicilio['longitud']?.toString() ?? '');
      if (lat != null && lng != null) {
        latSum += lat;
        lngSum += lng;
        count++;
      }
    }

    if (count == 0) return const LatLng(19.0414, -98.2063);
    return LatLng(latSum / count, lngSum / count);
  }

  // ═══════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final totalParadas = _paradas.length;
    final progreso = totalParadas > 0 ? _visitadas / totalParadas : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Ruta de Visitas',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        surfaceTintColor: AppColors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_rutaIniciada) {
              _finalizarRuta();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.cardBorder.withValues(alpha: 0.5),
            height: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _ruta == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 64,
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No hay ruta asignada para hoy',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Info de ruta + progreso
                Container(
                  padding: const EdgeInsets.all(14),
                  color: AppColors.white,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _rutaIniciada
                                      ? 'Ruta en curso'
                                      : 'Progreso de ruta',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _rutaIniciada
                                        ? AppColors.success
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_visitadas de $totalParadas paradas visitadas',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_rutaIniciada)
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          if (_rutaIniciada) const SizedBox(width: 8),
                          Text(
                            '${(progreso * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progreso,
                          minHeight: 8,
                          backgroundColor: AppColors.cardBorder,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.success,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_rutaIniciada) ...[
                            _buildLeyenda('Tú', Colors.blue),
                            const SizedBox(width: 16),
                          ],
                          _buildLeyenda('Visitada', AppColors.success),
                          const SizedBox(width: 16),
                          _buildLeyenda('Pendiente', AppColors.warning),
                        ],
                      ),
                    ],
                  ),
                ),

                // Mapa
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _getCentro(),
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.preventrack.app',
                      ),
                      PolylineLayer(
                        polylines: _rutaCalles.isNotEmpty
                            ? [
                                Polyline(
                                  points: _rutaCalles,
                                  strokeWidth: 4,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ]
                            : _buildRutaLinea(),
                      ),
                      MarkerLayer(markers: _buildMarkers()),
                    ],
                  ),
                ),

                // Botón Iniciar / Finalizar ruta
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border(
                      top: BorderSide(
                        color: AppColors.cardBorder.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _rutaIniciada
                        ? OutlinedButton.icon(
                            onPressed: _finalizarRuta,
                            icon: const Icon(
                              Icons.stop_circle_outlined,
                              size: 20,
                            ),
                            label: const Text(
                              'Finalizar ruta',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _iniciarRuta,
                            icon: const Icon(
                              Icons.play_circle_outline,
                              size: 20,
                            ),
                            label: const Text(
                              'Iniciar ruta',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLeyenda(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textPrimary.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
