import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_theme.dart';
import '../services/api_service.dart';
import 'seleccionar_ubicacion_screen.dart';

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

  double? _latitud;
  double? _longitud;
  List<dynamic> _sugerencias = [];
  bool _buscandoDireccion = false;
  bool _direccionSeleccionada = false;
  Timer? _debounce;
  bool _guardando = false;

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
    final lat = double.tryParse(lugar['lat']?.toString() ?? '');
    final lon = double.tryParse(lugar['lon']?.toString() ?? '');
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
      _latitud = lat;
      _longitud = lon;
      _sugerencias = [];
      _direccionSeleccionada = true;
    });
  }

  Future<void> _abrirMapa() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SeleccionarUbicacionScreen(
          latitudInicial: _latitud,
          longitudInicial: _longitud,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitud = result['latitud'];
        _longitud = result['longitud'];
        _direccionSeleccionada = true;

        // Si el geocoding inverso devolvió datos, llenar los campos
        if (result['direccion'] != null &&
            _direccionController.text.trim().isEmpty) {
          _direccionController.text = result['direccion'];
        }
        if (result['municipio'] != null &&
            _municipioController.text.trim().isEmpty) {
          _municipioController.text = result['municipio'];
        }
      });
    }
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

          await _api.post('clientes/$clienteId/domicilios', body: domicilioBody);
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
          mensaje = errors.values
              .expand((e) => e is List ? e : [e])
              .join('\n');
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
                          // Campo de dirección con búsqueda
                          TextFormField(
                            controller: _direccionController,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'La dirección es obligatoria';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              _direccionSeleccionada = false;
                              _latitud = null;
                              _longitud = null;
                              _buscarDireccion(value);
                            },
                            decoration: InputDecoration(
                              labelText: 'Dirección *',
                              hintText: 'Escribe para buscar...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary.withValues(alpha: 0.3),
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
                                  : _direccionSeleccionada
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: AppColors.success,
                                          size: 20,
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
                                border: Border.all(color: AppColors.cardBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Column(
                                  children: _sugerencias.map((lugar) {
                                    final nombre = lugar['display_name'] ?? '';
                                    final tipo = lugar['type'] ?? '';
                                    return InkWell(
                                      onTap: () => _seleccionarDireccion(lugar),
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
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
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

                          const SizedBox(height: 10),

                          // Botón "Ubicar en mapa"
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton.icon(
                              onPressed: _abrirMapa,
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: Text(
                                _latitud != null
                                    ? 'Cambiar ubicación en mapa'
                                    : 'Ubicar en mapa',
                                style: const TextStyle(fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),

                          // Indicador de coordenadas
                          if (_latitud != null && _longitud != null)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.gps_fixed,
                                    size: 14,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Coordenadas: ${_latitud!.toStringAsFixed(4)}, ${_longitud!.toStringAsFixed(4)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 14),
                          _buildCampo(
                            controller: _municipioController,
                            label: 'Municipio',
                            hint: 'Se llena automáticamente',
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
