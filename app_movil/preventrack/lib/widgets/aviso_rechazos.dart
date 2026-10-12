import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/sync_service.dart';

// Muestra una sola vez los avisos de entregas que la API rechazó al
// sincronizar (p. ej. el pedido se canceló mientras no había conexión).
Future<void> mostrarRechazosSincronizacion(BuildContext context) async {
  final avisos = SyncService.tomarRechazos();
  if (avisos.isEmpty || !context.mounted) return;

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Entregas sin registrar'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final aviso in avisos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(aviso),
            ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
