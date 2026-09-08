import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';

class CrearClienteScreen extends StatefulWidget {
  const CrearClienteScreen({super.key});

  @override
  State<CrearClienteScreen> createState() => _CrearClienteScreenState();
}

class _CrearClienteScreenState extends State<CrearClienteScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nombreNegocioController = TextEditingController();
  final _propietarioController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _zonaController = TextEditingController();
  final _direccionController = TextEditingController();
  final _municipioController = TextEditingController();

  // GPS
  double? _latitud;
  double? _longitud;
  bool _capturandoGps = false;
  String? _gpsError;

  // Nominatim
  List<dynamic> _sugerencias = [];
  bool _buscandoDireccion = false;
  Timer? _debounce;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _capturarUbicacion();
  }

  @override
  void dispose() {
    _nombreNegocioController.dispose();
    _propietarioController.dispose();
    _telefonoController.dispose();
    _zonaController.dispose();
    _direccionController.dispose();
    _municipioController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _capturarUbicacion() async {
    // En web no capturamos GPS
    if (kIsWeb) return;

    setState(() {
      _capturandoGps = true;
      _gpsError = null;
    });

    try {
      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _gpsError = 'Activa el GPS de tu dispositivo';
          _capturandoGps = false;
        });
        return;
      }

      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _gpsError = 'Permiso de ubicación denegado';
            _capturandoGps = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _gpsError = 'Permiso de ubicación denegado permanentemente. Actívalo en Ajustes.';
          _capturandoGps = false;
        });
        return;
      }

      // Obtener ubicación
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;

      setState(() {
        _latitud = position.latitude;
        _longitud = position.longitude;
        _capturandoGps = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gpsError = 'No se pudo obtener la ubicación';
        _capturandoGps = false;
      });
    }
  }

  void _buscarDireccion(String query) {
    _debounce?.cancel();

    if (query.length < 3) {
      setState(() {
        _sugerencias = [];
        _buscandoDireccion = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _buscandoDireccion = true);

      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(query)}'
          '&format=json'
          '&limit=5'
          '&countrycodes=mx'
          '&addressdetails=1',
        );

        final response = await http.get(url, headers: {
          'User-Agent': 'PreventrackApp/1.0',
          'Accept': 'application/json',
        });

        if (!mounted) return;

        if (response.statusCode == 200) {
          final results = jsonDecode(response.body) as List<dynamic>;
          setState(() {
            _sugerencias = results;
            _buscandoDireccion = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _sugerencias = [];
            _buscandoDireccion = false;
          });
        }
      }
    });
  }

  void _seleccionarDireccion(Map<String, dynamic> lugar) {
    final displayName = lugar['display_name'] ?? '';
    final address = lugar['address'] as Map<String, dynamic>? ?? {};

    final municipio = address['city'] ??
        address['town'] ??
        address['village'] ??
        address['municipality'] ??
        address['county'] ??
        '';

    setState(() {
      _direccionController.text = displayName;
      _municipioController.text = municipio;
      _sugerencias = [];
    });
  }

  Future<void> _guardarCliente() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final resultCliente = await _api.post('clientes', body: {
        'nombre_negocio': _nombreNegocioController.text.trim(),
        'propietario': _propietarioController.text.trim().isEmpty
            ? null
            : _propietarioController.text.trim(),
        'telefono': _telefonoController.text.trim().isEmpty
            ? null
            : _telefonoController.text.trim(),
        'zona': _zonaController.text.trim().isEmpty
            ? null
            : _zonaController.text.trim(),
        'estado': 'activo',
      });

      if (!mounted) return;

      if (resultCliente['statusCode'] == 201) {
        final clienteId = resultCliente['data']['id'];

        if (_direccionController.text.trim().isNotEmpty) {
          final domicilioBody = <String, dynamic>{
            'direccion': _direccionController.text.trim(),
            'municipio': _municipioController.text.trim().isEmpty
                ? null
                : _municipioController.text.trim(),
            'es_principal': true,
          };

          if (_latitud != null && _longitud != null) {
            domicilioBody['latitud'] = _latitud;
            domicilioBody['longitud'] = _longitud;
          }

          await _api.post('clientes/$clienteId/domicilios',
              body: domicilioBody);
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente creado correctamente'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pop(context, true);
      } else {
        final errores = resultCliente['data'];
        String mensaje = 'Error al crear el cliente';

        if (errores is Map && errores.containsKey('errors')) {
          final errors = errores['errors'] as Map<String, dynamic>;
          mensaje =
              errors.values.expand((e) => e is List ? e : [e]).join('\n');
        } else if (errores is Map && errores.containsKey('message')) {
          mensaje = errores['message'];
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
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

    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Nuevo Cliente',
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── GPS automático ──
                    _buildGpsIndicator(),
                    const SizedBox(height: 16),

                    // ── Información del negocio ──
                    const Text(
                      'INFORMACIÓN DEL NEGOCIO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          _buildCampo(
                            controller: _nombreNegocioController,
                            label: 'Nombre del negocio *',
                            hint: 'Ej: Abarrotes Don Juan',
                            icono: Icons.store_outlined,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'El nombre es obligatorio';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildCampo(
                            controller: _propietarioController,
                            label: 'Propietario',
                            hint: 'Nombre del dueño (opcional)',
                            icono: Icons.person_outline,
                          ),
                          const SizedBox(height: 14),
                          _buildCampo(
                            controller: _telefonoController,
                            label: 'Teléfono',
                            hint: '55 1234 5678 (opcional)',
                            icono: Icons.phone_outlined,
                            teclado: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          _buildCampo(
                            controller: _zonaController,
                            label: 'Zona',
                            hint: 'Ej: Norte, Centro (opcional)',
                            icono: Icons.map_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Domicilio ──
                    const Text(
                      'DOMICILIO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          // Campo de dirección con búsqueda Nominatim
                          TextFormField(
                            controller: _direccionController,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'La dirección es obligatoria';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              _buscarDireccion(value);
                            },
                            decoration: InputDecoration(
                              labelText: 'Dirección *',
                              hintText: 'Escribe la dirección...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary
                                    .withValues(alpha: 0.3),
                              ),
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              suffixIcon: _buscandoDireccion
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  : null,
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppColors.error,
                                  width: 1,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppColors.error,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),

                          // Sugerencias de Nominatim
                          if (_sugerencias.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: AppColors.cardBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Column(
                                  children: _sugerencias.map((lugar) {
                                    final nombre =
                                        lugar['display_name'] ?? '';
                                    return InkWell(
                                      onTap: () =>
                                          _seleccionarDireccion(lugar),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: AppColors.cardBorder
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.place_outlined,
                                              size: 18,
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.5),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                nombre,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.textPrimary,
                                                ),
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),

                          const SizedBox(height: 14),
                          _buildCampo(
                            controller: _municipioController,
                            label: 'Municipio',
                            hint: 'Escribe el municipio',
                            icono: Icons.location_city_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // Botón Guardar
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
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardarCliente,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  _guardando ? 'Guardando...' : 'Guardar Cliente',
                  style: const TextStyle(
                    fontSize: 16,
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
          ),
        ],
      ),
    );
  }

  Widget _buildGpsIndicator() {
    if (kIsWeb) return const SizedBox.shrink();

    Color bgColor;
    Color iconColor;
    IconData icono;
    String texto;

    if (_capturandoGps) {
      bgColor = AppColors.secondary.withValues(alpha: 0.06);
      iconColor = AppColors.secondary;
      icono = Icons.gps_not_fixed;
      texto = 'Capturando ubicación GPS...';
    } else if (_gpsError != null) {
      bgColor = AppColors.warning.withValues(alpha: 0.06);
      iconColor = AppColors.warning;
      icono = Icons.gps_off;
      texto = _gpsError!;
    } else if (_latitud != null) {
      bgColor = AppColors.success.withValues(alpha: 0.06);
      iconColor = AppColors.success;
      icono = Icons.gps_fixed;
      texto =
          'Ubicación capturada: ${_latitud!.toStringAsFixed(4)}, ${_longitud!.toStringAsFixed(4)}';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          _capturandoGps
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor,
                  ),
                )
              : Icon(icono, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: iconColor,
              ),
            ),
          ),
          if (_gpsError != null)
            GestureDetector(
              onTap: _capturarUbicacion,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Reintentar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCampo({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icono,
    TextInputType teclado = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: teclado,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary.withValues(alpha: 0.3),
        ),
        prefixIcon: Icon(icono, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
