import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';

// Monitoreo del equipo (solo administrador): ubicación de cada preventista,
// su jornada y el avance de su ruta del día. Usa los mismos datos que el
// monitoreo del panel web (/monitoreo) y se actualiza cada 30 segundos.
class MonitoreoScreen extends StatefulWidget {
  const MonitoreoScreen({super.key});

  @override
  State<MonitoreoScreen> createState() => _MonitoreoScreenState();
}

class _MonitoreoScreenState extends State<MonitoreoScreen> {
  final ApiService _api = ApiService();
  final MapController _mapController = MapController();

  List<dynamic> _equipo = [];
  bool _cargando = true;
  bool _consultando = false;
  String? _error;
  DateTime? _actualizado;
  Timer? _timer;

  int? _seleccionadoId;
  bool _mostrarRuta = false;
  bool _mapaListo = false;
  bool _encuadreInicial = false;

  static const _centroPorDefecto = LatLng(19.0414, -98.2063); // Puebla

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_consultando) return;
    _consultando = true;
    try {
      final result = await _api.get('monitoreo');
      if (!mounted) return;
      if (result['statusCode'] == 200) {
        setState(() {
          _equipo = result['data'] is List ? result['data'] : [];
          _error = null;
          _actualizado = DateTime.now();
          _cargando = false;
        });
        if (!_encuadreInicial) {
          _encuadreInicial = true;
          _encuadrar();
        }
      } else {
        setState(() {
          _error = result['statusCode'] == 403
              ? 'Solo el administrador puede ver el monitoreo.'
              : 'No se pudo cargar el monitoreo.';
          _cargando = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      // Se conservan los últimos datos; solo se avisa
      setState(() {
        _error = 'Sin conexión. Se necesita conexión para ver las ubicaciones.';
        _cargando = false;
      });
    } finally {
      _consultando = false;
    }
  }

  // ── Datos de cada preventista ──

  Map<String, dynamic>? get _seleccionado {
    for (final m in _equipo) {
      if (m['id'] == _seleccionadoId) return m as Map<String, dynamic>;
    }
    return null;
  }

  LatLng? _ubicacion(Map<String, dynamic> m) {
    final u = m['ubicacion'];
    if (u == null) return null;
    final lat = double.tryParse(u['latitud'].toString());
    final lng = double.tryParse(u['longitud'].toString());
    return lat != null && lng != null ? LatLng(lat, lng) : null;
  }

  // Ubicación en vivo de los últimos 10 minutos
  bool _esReciente(Map<String, dynamic> m) =>
      m['ubicacion']?['reciente'] == true;

  Color _colorDe(Map<String, dynamic> m) {
    final hex = (m['color'] ?? '').toString().replaceFirst('#', '');
    final valor = int.tryParse(hex, radix: 16);
    return hex.length == 6 && valor != null
        ? Color(0xFF000000 | valor)
        : AppColors.secondary;
  }

  String _inicial(Map<String, dynamic> m) {
    final nombre = (m['nombre'] ?? '').toString().trim();
    return nombre.isEmpty ? '?' : nombre[0].toUpperCase();
  }

  String _hora(String? fecha) {
    if (fecha == null) return '';
    try {
      final dt = DateTime.parse(fecha).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _haceCuanto(String? fecha) {
    if (fecha == null) return '';
    try {
      final minutos = DateTime.now()
          .difference(DateTime.parse(fecha).toLocal())
          .inMinutes;
      if (minutos < 1) return 'hace un momento';
      if (minutos < 60) return 'hace $minutos min';
      final horas = minutos ~/ 60;
      return horas < 24 ? 'hace $horas h' : 'hace más de un día';
    } catch (_) {
      return '';
    }
  }

  String _textoUbicacion(Map<String, dynamic> m) {
    final u = m['ubicacion'];
    if (u == null) return 'Sin ubicación hoy';
    if (u['origen'] == 'en_vivo') {
      return 'Ubicación en vivo · ${_haceCuanto(u['actualizada']?.toString())}';
    }
    return 'Ubicación del inicio de jornada';
  }

  List<dynamic> _paradas(Map<String, dynamic> m) =>
      (m['ruta']?['paradas'] as List<dynamic>?) ?? [];

  Color _colorParada(String? estado) {
    switch (estado) {
      case 'visitada':
        return AppColors.success;
      case 'no_disponible':
        return AppColors.warning;
      default:
        return AppColors.secondary;
    }
  }

  // ── Mapa ──

  // Acomoda el mapa para que se vean todos los preventistas o, si se está
  // viendo una ruta, la ruta y su preventista
  void _encuadrar() {
    if (!_mapaListo) return;
    final puntos = <LatLng>[];
    final sel = _seleccionado;
    if (sel != null && _mostrarRuta) {
      for (final p in _paradas(sel)) {
        puntos.add(LatLng(p['latitud'] * 1.0, p['longitud'] * 1.0));
      }
      final u = _ubicacion(sel);
      if (u != null) puntos.add(u);
    } else {
      for (final m in _equipo) {
        final u = _ubicacion(m as Map<String, dynamic>);
        if (u != null) puntos.add(u);
      }
    }
    if (puntos.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(puntos),
        padding: const EdgeInsets.all(48),
        maxZoom: 16,
      ),
    );
  }

  void _seleccionar(Map<String, dynamic> m) {
    setState(() {
      if (_seleccionadoId != m['id']) _mostrarRuta = false;
      _seleccionadoId = m['id'];
    });
    final u = _ubicacion(m);
    if (u != null && _mapaListo) {
      _mapController.move(u, 15);
    }
  }

  void _alternarRuta() {
    setState(() => _mostrarRuta = !_mostrarRuta);
    _encuadrar();
  }

  // ── Interfaz ──

  @override
  Widget build(BuildContext context) {
    final activos = _equipo.where((m) => m['jornada_activa'] == true).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Monitoreo',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                // Resumen
                Container(
                  width: double.infinity,
                  color: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$activos de ${_equipo.length} con jornada activa',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_actualizado != null)
                        Text(
                          'Actualizado ${_hora(_actualizado!.toIso8601String())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_error != null)
                  Container(
                    width: double.infinity,
                    color: AppColors.warning.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(_error!, style: const TextStyle(fontSize: 12)),
                  ),
                // Mapa
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: _buildMapa(),
                ),
                // Ficha del seleccionado + lista del equipo
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cargar,
                    color: AppColors.primary,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      children: [
                        if (_seleccionado != null) ...[
                          _buildFicha(_seleccionado!),
                          const SizedBox(height: 12),
                        ],
                        if (_equipo.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No hay preventistas activos.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        for (final m in _equipo)
                          _buildFilaEquipo(m as Map<String, dynamic>),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMapa() {
    final sel = _seleccionado;
    final paradas = sel != null && _mostrarRuta ? _paradas(sel) : [];
    final puntosRuta = [
      for (final p in paradas) LatLng(p['latitud'] * 1.0, p['longitud'] * 1.0),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _centroPorDefecto,
        initialZoom: 12,
        onMapReady: () {
          _mapaListo = true;
          _encuadrar();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.preventrack.app',
        ),
        if (puntosRuta.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: puntosRuta,
                strokeWidth: 3,
                color: _colorDe(sel!).withValues(alpha: 0.7),
              ),
            ],
          ),
        // Paradas de la ruta del seleccionado
        MarkerLayer(
          markers: [
            for (var i = 0; i < paradas.length; i++)
              Marker(
                point: puntosRuta[i],
                width: 26,
                height: 26,
                child: Container(
                  decoration: BoxDecoration(
                    color: _colorParada(paradas[i]['estado']),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${paradas[i]['orden'] ?? i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Preventistas
        MarkerLayer(
          markers: [
            for (final m in _equipo)
              if (_ubicacion(m as Map<String, dynamic>) != null)
                Marker(
                  point: _ubicacion(m)!,
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => _seleccionar(m),
                    child: Opacity(
                      // Apagado: ubicación de hace más de 10 min
                      opacity: _esReciente(m) ? 1 : 0.45,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _colorDe(m),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: m['id'] == _seleccionadoId
                                ? AppColors.primary
                                : Colors.white,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _inicial(m),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar(Map<String, dynamic> m, {double tam = 36}) {
    return Opacity(
      opacity: _ubicacion(m) == null || _esReciente(m) ? 1 : 0.45,
      child: Container(
        width: tam,
        height: tam,
        decoration: BoxDecoration(color: _colorDe(m), shape: BoxShape.circle),
        child: Center(
          child: Text(
            _inicial(m),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFicha(Map<String, dynamic> m) {
    final activa = m['jornada_activa'] == true;
    final ruta = m['ruta'] ?? {};
    final total = (ruta['total_paradas'] ?? 0) as int;
    final visitadas = (ruta['paradas_visitadas'] ?? 0) as int;
    final tieneParadas = _paradas(m).isNotEmpty;
    final gris = AppColors.textPrimary.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(m),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m['nombre'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      activa
                          ? 'Jornada activa desde ${_hora(m['hora_inicio']?.toString())}'
                          : 'Sin jornada activa',
                      style: TextStyle(
                        fontSize: 12,
                        color: activa ? AppColors.success : gris,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Cerrar',
                onPressed: () => setState(() {
                  _seleccionadoId = null;
                  _mostrarRuta = false;
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: gris),
              const SizedBox(width: 6),
              Text(
                _textoUbicacion(m),
                style: TextStyle(fontSize: 12, color: gris),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.route_outlined, size: 16, color: gris),
              const SizedBox(width: 6),
              Text(
                ruta['tiene_ruta_hoy'] == true
                    ? 'Ruta: $visitadas de $total paradas'
                    : 'Sin ruta hoy',
                style: TextStyle(fontSize: 12, color: gris),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: visitadas / total,
                minHeight: 6,
                backgroundColor: AppColors.cardBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.success,
                ),
              ),
            ),
          ],
          if (tieneParadas) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _alternarRuta,
                icon: Icon(
                  _mostrarRuta ? Icons.visibility_off_outlined : Icons.route,
                  size: 18,
                ),
                label: Text(_mostrarRuta ? 'Ocultar su ruta' : 'Ver su ruta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilaEquipo(Map<String, dynamic> m) {
    final activa = m['jornada_activa'] == true;
    final ruta = m['ruta'] ?? {};
    final seleccionado = m['id'] == _seleccionadoId;
    final u = m['ubicacion'];

    final detalle = [
      activa ? 'Activa' : 'Sin jornada',
      if (u == null)
        'sin ubicación'
      else if (u['origen'] == 'en_vivo')
        _haceCuanto(u['actualizada']?.toString())
      else
        'ubicación de inicio',
    ].join(' · ');

    return GestureDetector(
      onTap: () => _seleccionar(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: seleccionado ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            _buildAvatar(m, tam: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['nombre'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    detalle,
                    style: TextStyle(
                      fontSize: 12,
                      color: activa
                          ? AppColors.success
                          : AppColors.textPrimary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              ruta['tiene_ruta_hoy'] == true
                  ? '${ruta['paradas_visitadas'] ?? 0}/${ruta['total_paradas'] ?? 0}'
                  : '—',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
