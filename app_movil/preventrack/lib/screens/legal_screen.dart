import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> with SingleTickerProviderStateMixin {
  bool _avisoAceptado = false;
  bool _terminosAceptados = false;
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _aceptarTerminos() async {
    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final token = await authService.getToken();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/usuarios/aceptar-terminos'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        auth.usuario?['terminos_aceptados'] = true;
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al aceptar terminos. Intenta de nuevo.')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  String get _avisoPrivacidad {
    return "Aviso de Privacidad Preventrack\n\n"
        "Para Preventrack, la seguridad de sus datos es nuestra prioridad. "
        "Este aviso describe como recopilamos, usamos y protegemos su informacion "
        "personal en el contexto de nuestras operaciones de logistica y distribucion.\n\n"
        "1. Recopilacion de Datos: Recopilamos informacion necesaria para la gestion "
        "de rutas, identificacion de clientes y procesamiento de pedidos, incluyendo "
        "ubicacion en tiempo real para optimizacion de entregas.\n\n"
        "2. Uso de la Informacion: Los datos se utilizan exclusivamente para mejorar "
        "la eficiencia operativa, asegurar la trazabilidad de los productos y facilitar "
        "la comunicacion entre los agentes de campo y la administracion.\n\n"
        "3. Proteccion de Datos: Implementamos protocolos de cifrado de grado empresarial "
        "y controles de acceso estrictos para garantizar que su informacion este protegida "
        "contra accesos no autorizados.\n\n"
        "4. Datos Personales Recabados: Nombre completo, numero de telefono, nombre de "
        "usuario y contrasena, datos de geolocalizacion durante el uso de la aplicacion, "
        "informacion de jornada laboral.\n\n"
        "5. Derechos ARCO: Usted tiene derecho a Acceder, Rectificar, Cancelar u Oponerse "
        "al tratamiento de sus datos personales contactando al administrador del sistema.\n\n"
        "6. Modificaciones: Nos reservamos el derecho de modificar este aviso de privacidad. "
        "Cualquier cambio sera notificado a traves de la aplicacion.\n\n"
        "Fecha de ultima actualizacion: Julio 2026.";
  }

  String get _terminosCondiciones {
    return "Terminos y Condiciones de Uso\n\n"
        "Al utilizar la aplicacion Preventrack, usted acepta los siguientes "
        "terminos y condiciones:\n\n"
        "1. Uso de la Aplicacion: Preventrack es un sistema de preventa y distribucion "
        "comercial disenado para uso exclusivo del personal autorizado por la Empresa.\n\n"
        "2. Cuenta de Usuario: Cada usuario recibe credenciales unicas de acceso. "
        "Es responsabilidad del usuario mantener la confidencialidad de sus credenciales. "
        "No esta permitido compartir cuentas de usuario. La Empresa puede bloquear o "
        "eliminar cuentas en cualquier momento.\n\n"
        "3. Obligaciones del Usuario: Utilizar la aplicacion unicamente para fines "
        "laborales autorizados. Mantener actualizada su informacion personal. Reportar "
        "cualquier uso no autorizado de su cuenta. No intentar acceder a funciones o "
        "datos no autorizados para su rol.\n\n"
        "4. Geolocalizacion: La aplicacion registra su ubicacion al momento de crear "
        "pedidos. Esta informacion se utiliza para verificar y optimizar las operaciones. "
        "El registro de ubicacion es un requisito operativo del sistema.\n\n"
        "5. Propiedad Intelectual: Todo el contenido, diseno y funcionalidad de Preventrack "
        "es propiedad de la Empresa. Queda prohibida su reproduccion total o parcial.\n\n"
        "6. Limitacion de Responsabilidad: La Empresa no sera responsable por interrupciones "
        "del servicio, perdida de datos por fallos tecnicos, o uso indebido de la aplicacion "
        "por parte del usuario.\n\n"
        "7. Jornada Laboral: El registro de jornada laboral a traves de la aplicacion tiene "
        "validez como control de asistencia. El usuario es responsable de registrar "
        "correctamente sus horarios.\n\n"
        "8. Modificaciones: La Empresa se reserva el derecho de modificar estos terminos "
        "en cualquier momento. Los cambios entraran en vigor al ser publicados en la aplicacion.\n\n"
        "Fecha de ultima actualizacion: Julio 2026.";
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final nombre = auth.usuario?['nombre'] ?? 'U';
    final inicial = nombre[0].toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Centro Legal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.secondary,
              child: Text(
                inicial,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitulo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            color: AppColors.background,
            child: Text(
              'Revisa y acepta los lineamientos de uso y privacidad',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
          ),

          // Tabs
          Container(
            color: AppColors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textPrimary.withValues(alpha: 0.5),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Aviso de Privacidad'),
                Tab(text: 'Terminos y Condiciones'),
              ],
            ),
          ),

          // Contenido de tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContenidoLegal(_avisoPrivacidad),
                _buildContenidoLegal(_terminosCondiciones),
              ],
            ),
          ),

          // Checkboxes y boton
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(
                top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.5)),
              ),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _avisoAceptado = !_avisoAceptado),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _avisoAceptado,
                          onChanged: (v) => setState(() => _avisoAceptado = v ?? false),
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          side: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.3)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'He leido y acepto el Aviso de Privacidad',
                          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => setState(() => _terminosAceptados = !_terminosAceptados),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _terminosAceptados,
                          onChanged: (v) => setState(() => _terminosAceptados = v ?? false),
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          side: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.3)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'He leido y acepto los Terminos y Condiciones',
                          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_avisoAceptado && _terminosAceptados && !_isLoading)
                        ? _aceptarTerminos
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_avisoAceptado && _terminosAceptados)
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.3),
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                      disabledForegroundColor: AppColors.white.withValues(alpha: 0.7),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('CONTINUAR'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 18),
                            ],
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

  Widget _buildContenidoLegal(String texto) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 14,
          height: 1.7,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
