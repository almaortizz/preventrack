import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../config/app_theme.dart';

class SeleccionarUbicacionScreen extends StatefulWidget {
  final double? latitudInicial;
  final double? longitudInicial;

  const SeleccionarUbicacionScreen({
    super.key,
    this.latitudInicial,
    this.longitudInicial,
  });

  @override
  State<SeleccionarUbicacionScreen> createState() =>
      _SeleccionarUbicacionScreenState();
}

class _SeleccionarUbicacionScreenState
    extends State<SeleccionarUbicacionScreen> {
  final MapController _mapController = MapController();
  LatLng? _puntoSeleccionado;
  String? _direccionReversa;
  String? _municipioReverso;
  bool _buscandoDireccion = false;
  bool _vistaSatelite = false;

  // Tiles
  static const String _urlMapa =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _urlSatelite =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  @override
  void initState() {
    super.initState();
    if (widget.latitudInicial != null && widget.longitudInicial != null) {
      _puntoSeleccionado = LatLng(
        widget.latitudInicial!,
        widget.longitudInicial!,
      );
    }
  }

  LatLng get _centroInicial {
    if (_puntoSeleccionado != null) return _puntoSeleccionado!;
    return const LatLng(19.0414, -98.2063);
  }

  Future<void> _buscarDireccionReversa(LatLng punto) async {
    setState(() => _buscandoDireccion = true);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${punto.latitude}'
        '&lon=${punto.longitude}'
        '&format=json'
        '&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'PreventrackApp/1.0',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final municipio =
            address['city'] ??
            address['town'] ??
            address['village'] ??
            address['municipality'] ??
            address['county'] ??
            '';

        final road = address['road'] ?? '';
        final suburb = address['suburb'] ?? address['neighbourhood'] ?? '';
        final partes = [
          road,
          suburb,
          municipio,
        ].where((s) => s.toString().isNotEmpty).toList();

        setState(() {
          _direccionReversa = partes.isNotEmpty ? partes.join(', ') : null;
          _municipioReverso = municipio.isNotEmpty ? municipio : null;
          _buscandoDireccion = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _direccionReversa = null;
          _municipioReverso = null;
          _buscandoDireccion = false;
        });
      }
    }
  }

  void _onTapMapa(TapPosition tapPosition, LatLng punto) {
    setState(() {
      _puntoSeleccionado = punto;
      _direccionReversa = null;
      _municipioReverso = null;
    });
    _buscarDireccionReversa(punto);
  }

  void _confirmar() {
    if (_puntoSeleccionado == null) return;

    Navigator.pop(context, {
      'latitud': _puntoSeleccionado!.latitude,
      'longitud': _puntoSeleccionado!.longitude,
      'direccion': _direccionReversa,
      'municipio': _municipioReverso,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Ubicar en mapa',
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
      body: Column(
        children: [
          // Instrucciones
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.primary.withValues(alpha: 0.06),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 18,
                  color: AppColors.primary.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Toca el mapa para marcar la ubicación del negocio',
                    style: TextStyle(fontSize: 13, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),

          // Mapa
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _centroInicial,
                    initialZoom: _puntoSeleccionado != null ? 16 : 10,
                    maxZoom: _vistaSatelite ? 17 : 19,
                    onTap: _onTapMapa,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _vistaSatelite ? _urlSatelite : _urlMapa,
                      userAgentPackageName: 'com.preventrack.app',
                      maxZoom: _vistaSatelite ? 17 : 19,
                    ),
                    // Capa de nombres sobre el satélite
                    if (_vistaSatelite)
                      TileLayer(
                        urlTemplate:
                            'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.preventrack.app',
                        maxZoom: 18,
                      ),
                    if (_puntoSeleccionado != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _puntoSeleccionado!,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_pin,
                              color: AppColors.error,
                              size: 50,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Botón cambiar vista (Mapa / Satélite)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildVistaBoton(
                          label: 'Mapa',
                          icono: Icons.map_outlined,
                          seleccionado: !_vistaSatelite,
                          onTap: () => setState(() => _vistaSatelite = false),
                          esIzquierdo: true,
                        ),
                        _buildVistaBoton(
                          label: 'Satélite',
                          icono: Icons.satellite_alt,
                          seleccionado: _vistaSatelite,
                          onTap: () => setState(() => _vistaSatelite = true),
                          esIzquierdo: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info del punto + botón confirmar
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
            child: Column(
              children: [
                if (_puntoSeleccionado != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.gps_fixed,
                              size: 14,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_puntoSeleccionado!.latitude.toStringAsFixed(6)}, ${_puntoSeleccionado!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        if (_buscandoDireccion)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Buscando dirección...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_direccionReversa != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.place_outlined,
                                  size: 14,
                                  color: AppColors.textPrimary.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _direccionReversa!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _puntoSeleccionado != null ? _confirmar : null,
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(
                      _puntoSeleccionado != null
                          ? 'Confirmar ubicación'
                          : 'Selecciona un punto en el mapa',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.cardBorder,
                      disabledForegroundColor: AppColors.textPrimary.withValues(
                        alpha: 0.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVistaBoton({
    required String label,
    required IconData icono,
    required bool seleccionado,
    required VoidCallback onTap,
    required bool esIzquierdo,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.horizontal(
            left: esIzquierdo ? const Radius.circular(10) : Radius.zero,
            right: !esIzquierdo ? const Radius.circular(10) : Radius.zero,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 16,
              color: seleccionado ? AppColors.white : AppColors.textPrimary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: seleccionado ? AppColors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
