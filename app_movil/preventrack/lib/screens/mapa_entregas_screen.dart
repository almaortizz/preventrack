import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import 'detalle_entrega_screen.dart';

class MapaEntregasScreen extends StatefulWidget {
  final List<dynamic> entregas;

  const MapaEntregasScreen({super.key, required this.entregas});

  @override
  State<MapaEntregasScreen> createState() => _MapaEntregasScreenState();
}

class _MapaEntregasScreenState extends State<MapaEntregasScreen> {
  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _entregasConUbicacion() {
    final resultado = <Map<String, dynamic>>[];

    for (var entrega in widget.entregas) {
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
      });
    }

    return resultado;
  }

  LatLng _getCentro(List<Map<String, dynamic>> entregas) {
    if (entregas.isEmpty) return const LatLng(19.0414, -98.2063);

    double latSum = 0, lngSum = 0;
    for (var e in entregas) {
      latSum += e['lat'] as double;
      lngSum += e['lng'] as double;
    }
    return LatLng(latSum / entregas.length, lngSum / entregas.length);
  }

  void _mostrarInfoEntrega(Map<String, dynamic> entrega) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
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
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    color: AppColors.secondary,
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
                      Text(
                        '\$${entrega['total']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
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
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DetalleEntregaScreen(ventaId: entrega['id']),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text(
                  'Ver detalle de entrega',
                  style: TextStyle(
                    fontSize: 14,
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entregasUbicadas = _entregasConUbicacion();
    final sinUbicacion = widget.entregas.length - entregasUbicadas.length;

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
                // Info
                Container(
                  padding: const EdgeInsets.all(14),
                  color: AppColors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entregasUbicadas.length} entrega${entregasUbicadas.length == 1 ? '' : 's'} en el mapa',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (sinUbicacion > 0)
                              Text(
                                '$sinUbicacion sin coordenadas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warning,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_shipping,
                              size: 14,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'En ruta',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
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
                      // Línea conectando entregas
                      if (entregasUbicadas.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: entregasUbicadas
                                  .map((e) => LatLng(
                                      e['lat'] as double, e['lng'] as double))
                                  .toList(),
                              strokeWidth: 3,
                              color: AppColors.secondary.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      // Marcadores
                      MarkerLayer(
                        markers: entregasUbicadas.asMap().entries.map((entry) {
                          final index = entry.key;
                          final entrega = entry.value;

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
                                  color: AppColors.secondary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.secondary
                                          .withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
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
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
