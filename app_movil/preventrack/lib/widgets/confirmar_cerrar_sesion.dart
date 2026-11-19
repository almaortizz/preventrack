import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

/// Antes de cerrar sesión: si el usuario tiene operaciones sin subir, intenta
/// subirlas; si siguen pendientes, le avisa que se quedan guardadas en este
/// celular. Regresa true si se puede cerrar la sesión.
Future<bool> confirmarCerrarSesion(BuildContext context) async {
  if (!DatabaseService.isAvailable) return true;
  if (await DatabaseService.contarOperacionesPendientes() == 0) return true;

  // Intentar subirlas primero (sin conexión falla rápido o al límite de tiempo)
  try {
    await SyncService.subirPendientes().timeout(const Duration(seconds: 20));
  } catch (_) {
    // sin conexión: se avisa abajo
  }

  final pendientes = await DatabaseService.contarOperacionesPendientes();
  if (pendientes == 0) return true;
  if (!context.mounted) return false;

  final operaciones = pendientes == 1
      ? '1 operación sin subir'
      : '$pendientes operaciones sin subir';

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Operaciones sin subir'),
      content: Text(
        'Tienes $operaciones. Se quedarán guardadas en este celular y se '
        'subirán cuando vuelvas a iniciar sesión aquí con conexión.\n\n'
        '¿Cerrar sesión de todos modos?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );
  return confirmar == true;
}
