import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';

class MapaEntregasScreen extends StatefulWidget {
  final List<dynamic> entregas;

  const MapaEntregasScreen({super.key, required this.entregas});

  @override
  State<MapaEntregasScreen> createState() => _MapaEntregasScreenState();
}

class _MapaEntregasScreenState extends State<MapaEntregasScreen> {
  final MapController _mapController = MapController();
  final ApiService _api = ApiService();

  bool _rutaIniciada = false;
  LatLng? _ubicacionActual;
  StreamSubscription<Position>? _positionStream;

  late List<dynamic> _entregas;
  int _entregadas = 0;

  // Ruta OSRM (líneas por calles)
  List<LatLng> _rutaCalles = [];
  bool _cargandoRuta = false;

  @override
  void initState() {
    super.initState();
    _entregas = List.from(widget.entregas);
    _cargarRutaOSRM();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════
  //  OSRM — RUTA POR CALLES
  // ═══════════════════════════════════════════

  Future<void> _cargarRutaOSRM() async {
    final puntos = <LatLng>[];

    for (var entrega in _entregas) {
      final domicilio = entrega['domicilio'];
      if (domicilio == null) continue;
      final lat = double.tryParse(domicilio['latitud']?.toString() ?? '');
      final lng = double.tryParse(domicilio['longitud']?.toString() ?? '');
      if (lat != null && lng != null) {
        puntos.add(LatLng(lat, lng));
      }
    }

    if (puntos.length < 2) return;

    setState(() => _cargandoRuta = true);

    try {
      // Construir coordenadas para OSRM: lng,lat;lng,lat;...
      final coords = puntos
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List<dynamic>?;

        if (routes != null && routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List<dynamic>;

          final rutaPuntos = coordinates.map((coord) {
            return LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            );
          }).toList();

          if (mounted) {
            setState(() {
              _rutaCalles = rutaPuntos;
              _cargandoRuta = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      // Si falla OSRM, se queda con líneas rectas
    }

    if (mounted) setState(() => _cargandoRuta = false);
  }

  // ═══════════════════════════════════════════
  //  GOOGLE MAPS — CÓMO LLEGAR
  // ═══════════════════════════════════════════

  Future<void> _abrirGoogleMaps(double lat, double lng, String nombre) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$lat,$lng'
      '&travelmode=driving',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir Google Maps'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════
  //  DATOS DE ENTREGAS
  // ═══════════════════════════════════════════

  List<Map<String, dynamic>> _entregasConUbicacion() {
    final resultado = <Map<String, dynamic>>[];

    for (var entrega in _entregas) {
      final domicilio = entrega['domicilio'];
      if (domicilio == null) continue;

      final lat = double.tryParse(domicilio['latitud']?.toString() ?? '');
      final lng = double.tryParse(domicilio['longitud']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      String clienteNombre = 'Cliente';
      final cliente = domicilio['cliente'];
      if (cliente != null) {
        clienteNombre = cliente['nombre_negocio'] ?? 'Cliente';
      }

      resultado.add({
        'id': entrega['id'],
        'lat': lat,
        'lng': lng,
        'nombre': clienteNombre,
        'direccion': domicilio['direccion'] ?? 'Sin dirección',
        'total': entrega['total'] ?? '0',
        'numero': entrega['numero_orden'] ?? '',
        'estado': entrega['estado'] ?? 'en_ruta',
      });
    }

    return resultado;
  }

  LatLng _getCentro(List<Map<String, dynamic>> entregas) {
    if (_rutaIniciada && _ubicacionActual != null) return _ubicacionActual!;
    if (entregas.isEmpty) return const LatLng(19.0414, -98.2063);

    double latSum = 0, lngSum = 0;
    for (var e in entregas) {
      latSum += e['lat'] as double;
      lngSum += e['lng'] as double;
    }
    return LatLng(latSum / entregas.length, lngSum / entregas.length);
  }

  // ═══════════════════════════════════════════
  //  INICIAR / FINALIZAR RUTA
  // ═══════════════════════════════════════════

  Future<void> _iniciarRuta() async {
    if (kIsWeb) {
      setState(() => _rutaIniciada = true);
      return;
    }

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
      });

      _mapController.move(_ubicacionActual!, 15);

      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
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
          content: Text('Ruta de entregas iniciada — GPS activo'),
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
    final pendientes = _entregas.where((e) => e['estado'] == 'en_ruta').length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar ruta de entregas'),
        content: Text(
          '¿Estás seguro de finalizar tu ruta?\n'
          'Entregas completadas: $_entregadas de ${_entregas.length}'
          '${pendientes > 0 ? '\n$pendientes pendientes' : ''}',
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
                  content: Text('Ruta de entregas finalizada'),
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
  //  ACCIONES DE ENTREGA
  // ═══════════════════════════════════════════

  Future<void> _registrarEntrega(int ventaId, BuildContext sheetContext) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar entrega'),
        content: const Text(
          '¿Confirmas que el pedido fue entregado al cliente?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sí, entregar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final result = await _api.post('ventas/$ventaId/marcar-entregado');
      if (!mounted) return;

      if (result['statusCode'] == 200) {
        Navigator.pop(sheetContext);
        setState(() {
          final index = _entregas.indexWhere((e) => e['id'] == ventaId);
          if (index != -1) {
            _entregas[index]['estado'] = 'entregado';
          }
          _entregadas++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido entregado correctamente'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        final msg = result['data']?['message'] ?? 'Error al marcar entrega';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
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

  Future<void> _marcarNoEntregado(
    int ventaId,
    BuildContext sheetContext,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No entregado'),
        content: const Text(
          '¿El pedido no pudo ser entregado? Regresará a estado pendiente.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('No entregado'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final result = await _api.post('ventas/$ventaId/marcar-no-entregado');
      if (!mounted) return;

      if (result['statusCode'] == 200) {
        Navigator.pop(sheetContext);
        setState(() {
          _entregas.removeWhere((e) => e['id'] == ventaId);
        });
        _cargarRutaOSRM(); // Recalcular ruta
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido regresado a pendiente'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        final msg = result['data']?['message'] ?? 'Error al actualizar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
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

  // ═══════════════════════════════════════════
  //  BOTTOM SHEET
  // ═══════════════════════════════════════════

  void _mostrarInfoEntrega(Map<String, dynamic> entrega) {
    final esEntregado = entrega['estado'] == 'entregado';

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
                    color: esEntregado
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    esEntregado ? Icons.check_circle : Icons.local_shipping,
                    color: esEntregado
                        ? AppColors.success
                        : AppColors.secondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entrega['nombre'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '\$${entrega['total']}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (esEntregado)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ENTREGADO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                    entrega['direccion'],
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Botones de entrega solo si no está entregado
            if (!esEntregado) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _registrarEntrega(entrega['id'], sheetContext),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text(
                    'Registrar Entrega',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _marcarNoEntregado(entrega['id'], sheetContext),
                  icon: const Icon(Icons.cancel_outlined, size: 20),
                  label: const Text(
                    'No entregado',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
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

  // ═══════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final entregasUbicadas = _entregasConUbicacion();
    final sinUbicacion = _entregas.length - entregasUbicadas.length;
    final total = entregasUbicadas.length;
    final progreso = total > 0 ? _entregadas / total : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Ruta de Entregas',
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
      body: entregasUbicadas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 64,
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No hay entregas con ubicación',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Los clientes no tienen coordenadas registradas',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Info + progreso
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
                                      : 'Entregas pendientes',
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
                                  '$_entregadas de $total entregas completadas',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                if (sinUbicacion > 0)
                                  Text(
                                    '$sinUbicacion sin coordenadas',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.warning,
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
                          _buildLeyenda('Entregado', AppColors.success),
                          const SizedBox(width: 16),
                          _buildLeyenda('Pendiente', AppColors.secondary),
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
                      initialCenter: _getCentro(entregasUbicadas),
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.preventrack.app',
                      ),
                      // Línea de ruta por calles (OSRM)
                      if (_rutaCalles.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _rutaCalles,
                              strokeWidth: 4,
                              color: AppColors.primary.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      // Marcadores
                      MarkerLayer(
                        markers: [
                          // Punto azul
                          if (_rutaIniciada && _ubicacionActual != null)
                            Marker(
                              point: _ubicacionActual!,
                              width: 28,
                              height: 28,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
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
                          // Entregas
                          ...entregasUbicadas.asMap().entries.map((entry) {
                            final index = entry.key;
                            final entrega = entry.value;
                            final esEntregado =
                                entrega['estado'] == 'entregado';
                            final color = esEntregado
                                ? AppColors.success
                                : AppColors.secondary;

                            return Marker(
                              point: LatLng(
                                entrega['lat'] as double,
                                entrega['lng'] as double,
                              ),
                              width: 44,
                              height: 44,
                              child: GestureDetector(
                                onTap: () => _mostrarInfoEntrega(entrega),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: esEntregado
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 20,
                                          )
                                        : Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),

                // Botón Iniciar / Finalizar
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
                              'Iniciar ruta de entregas',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
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
