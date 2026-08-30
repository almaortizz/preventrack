import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _cargarRuta();
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
      }
    } catch (e) {}
    setState(() => _isLoading = false);
  }

  Future<void> _marcarVisitada(int paradaId, BuildContext sheetContext) async {
    final rutaId = _ruta?['id'];
    if (rutaId == null) return;

    try {
      final result = await _api.post('rutas/$rutaId/visitar/$paradaId');

      if (!mounted) return;

      if (result['statusCode'] == 200) {
        // Cerrar el bottom sheet
        Navigator.pop(sheetContext);

        // Recargar los datos de la ruta
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
          SnackBar(
            content: Text(mensaje),
            backgroundColor: AppColors.error,
          ),
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

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

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
            onTap: () => _mostrarInfoParada(
              nombre,
              direccion,
              estado,
              orden,
              paradaId,
            ),
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
                              : 'Pendiente - Parada #$orden',
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
            // Botón "Marcar visitada" solo si está pendiente
            if (!esVisitada) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () => _marcarVisitada(paradaId, sheetContext),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text(
                    'Marcar visitada',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  LatLng _getCentro() {
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

    if (count == 0) return const LatLng(19.6860, -99.1265);
    return LatLng(latSum / count, lngSum / count);
  }

  @override
  Widget build(BuildContext context) {
    final totalParadas = _paradas.length;
    final progreso = totalParadas > 0 ? _visitadas / totalParadas : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mapa de Ruta',
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
          onPressed: () => Navigator.pop(context),
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
                    // Info de ruta
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
                                    const Text(
                                      'Progreso de ruta',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
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
                              _buildLeyenda('Visitada', AppColors.success),
                              const SizedBox(width: 20),
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
                          PolylineLayer(polylines: _buildRutaLinea()),
                          MarkerLayer(markers: _buildMarkers()),
                        ],
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
