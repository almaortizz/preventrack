import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/jornada_service.dart';

// El trabajo de campo del preventista (pedidos, clientes, visitas y entregas)
// requiere la jornada laboral iniciada. Usa la misma revisión que los mapas,
// así que funciona igual sin conexión. El administrador no se ve afectado.
// Regresa false (y avisa) si no puede continuar.
Future<bool> requiereJornadaActiva(BuildContext context) async {
  final usuario = Provider.of<AuthProvider>(context, listen: false).usuario;
  if (usuario?['rol_id'] == 1) return true;

  if (await JornadaService.tieneJornadaActiva()) return true;

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debes iniciar tu jornada laboral primero'),
        backgroundColor: AppColors.warning,
        duration: Duration(seconds: 3),
      ),
    );
  }
  return false;
}
