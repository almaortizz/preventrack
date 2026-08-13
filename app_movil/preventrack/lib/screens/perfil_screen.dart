import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final ApiService _api = ApiService();
  bool _isChangingPassword = false;
  final _passwordActualController = TextEditingController();
  final _passwordNuevoController = TextEditingController();
  final _passwordConfirmarController = TextEditingController();

  @override
  void dispose() {
    _passwordActualController.dispose();
    _passwordNuevoController.dispose();
    _passwordConfirmarController.dispose();
    super.dispose();
  }

  void _mostrarCambiarPassword() {
    _passwordActualController.clear();
    _passwordNuevoController.clear();
    _passwordConfirmarController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Cambiar contraseña',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _passwordNuevoController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordConfirmarController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar contraseña',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_passwordNuevoController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa la nueva contraseña')),
                );
                return;
              }
              if (_passwordNuevoController.text !=
                  _passwordConfirmarController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Las contraseñas no coinciden')),
                );
                return;
              }
              if (_passwordNuevoController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'La contraseña debe tener al menos 6 caracteres',
                    ),
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              setState(() => _isChangingPassword = true);

              try {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final userId = auth.usuario?['id'];
                final result = await _api.put(
                  'usuarios/$userId',
                  body: {'password': _passwordNuevoController.text},
                );

                if (result['statusCode'] == 200 && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contraseña actualizada correctamente'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error al cambiar la contraseña'),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error de conexión')),
                  );
                }
              }
              setState(() => _isChangingPassword = false);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final usuario = auth.usuario ?? {};
    final nombre = usuario['nombre'] ?? 'Usuario';
    final apellidos = usuario['apellidos'] ?? '';
    final telefono = usuario['telefono'] ?? 'Sin telefono';
    final user = usuario['usuario'] ?? '';
    final rol = usuario['rol'];
    final rolNombre = rol != null
        ? (rol['nombre'] ?? 'Colaborador')
        : 'Colaborador';
    final inicial = nombre[0].toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar y nombre
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        inicial,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$nombre $apellidos',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Preventrack - $rolNombre',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Detalles de la cuenta
            Text(
              'DETALLES DE LA CUENTA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary.withValues(alpha: 0.45),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),

            _buildCampoInfo(Icons.person_outline, 'Nombre', nombre),
            _buildCampoInfo(
              Icons.person_outline,
              'Apellidos',
              apellidos.isNotEmpty ? apellidos : 'Sin apellidos',
            ),
            _buildCampoInfo(Icons.phone_outlined, 'Telefono', telefono),
            _buildCampoInfo(Icons.alternate_email, 'Usuario', user),

            const SizedBox(height: 20),

            // Seguridad y soporte
            Text(
              'SEGURIDAD Y SOPORTE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary.withValues(alpha: 0.45),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),

            // Cambiar contraseña
            GestureDetector(
              onTap: _isChangingPassword ? null : _mostrarCambiarPassword,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Cambiar contraseña',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textPrimary.withValues(alpha: 0.3),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            // Centro legal
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/legal'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Centro Legal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.open_in_new,
                      color: AppColors.textPrimary.withValues(alpha: 0.3),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Version
            Center(
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.smartphone,
                      color: AppColors.textPrimary.withValues(alpha: 0.3),
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version app v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '2026 Preventrack. Todos los derechos reservados.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textPrimary.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Cerrar sesion
            Center(
              child: OutlinedButton(
                onPressed: () async {
                  final auth = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Cerrar Sesion',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoInfo(IconData icono, String label, String valor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textPrimary.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
