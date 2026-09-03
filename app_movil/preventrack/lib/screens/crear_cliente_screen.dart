import 'package:flutter/material.dart';
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

  // Campos del cliente
  final _nombreNegocioController = TextEditingController();
  final _propietarioController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _zonaController = TextEditingController();

  // Campos del domicilio
  final _direccionController = TextEditingController();
  final _municipioController = TextEditingController();

  bool _guardando = false;

  @override
  void dispose() {
    _nombreNegocioController.dispose();
    _propietarioController.dispose();
    _telefonoController.dispose();
    _zonaController.dispose();
    _direccionController.dispose();
    _municipioController.dispose();
    super.dispose();
  }

  Future<void> _guardarCliente() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      // 1. Crear el cliente
      final resultCliente = await _api.post(
        'clientes',
        body: {
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
        },
      );

      if (!mounted) return;

      if (resultCliente['statusCode'] == 201) {
        final clienteId = resultCliente['data']['id'];

        // 2. Crear el domicilio si tiene dirección
        if (_direccionController.text.trim().isNotEmpty) {
          await _api.post(
            'clientes/$clienteId/domicilios',
            body: {
              'direccion': _direccionController.text.trim(),
              'municipio': _municipioController.text.trim().isEmpty
                  ? null
                  : _municipioController.text.trim(),
              'es_principal': true,
            },
          );
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente creado correctamente'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pop(context, true); // true = se creó exitosamente
      } else {
        // Error de validación
        final errores = resultCliente['data'];
        String mensaje = 'Error al crear el cliente';

        if (errores is Map && errores.containsKey('errors')) {
          final errors = errores['errors'] as Map<String, dynamic>;
          mensaje = errors.values.expand((e) => e is List ? e : [e]).join('\n');
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
                          _buildCampo(
                            controller: _direccionController,
                            label: 'Dirección *',
                            hint: 'Calle, número, colonia',
                            icono: Icons.location_on_outlined,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'La dirección es obligatoria';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildCampo(
                            controller: _municipioController,
                            label: 'Municipio',
                            hint: 'Ej: Tultepec (opcional)',
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

          // Botón Guardar fijo abajo
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
