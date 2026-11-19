import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';

/// Franja que avisa que se están viendo datos guardados en el celular
/// (la última consulta con conexión) y de qué hora son.
class AvisoDatosGuardados extends StatelessWidget {
  final DateTime? fecha;
  final bool sinConexion;
  final EdgeInsetsGeometry margin;

  const AvisoDatosGuardados({
    super.key,
    required this.fecha,
    this.sinConexion = true,
    this.margin = EdgeInsets.zero,
  });

  /// "13:45" si es de hoy; "18/11 13:45" si es de otro día
  static String textoHora(DateTime? fecha) {
    if (fecha == null) return '';
    final ahora = DateTime.now();
    final esHoy =
        fecha.year == ahora.year &&
        fecha.month == ahora.month &&
        fecha.day == ahora.day;
    return DateFormat(esHoy ? 'HH:mm' : 'dd/MM HH:mm').format(fecha);
  }

  @override
  Widget build(BuildContext context) {
    final motivo = sinConexion ? 'Sin conexión' : 'No se pudo actualizar';
    final texto = fecha == null
        ? '$motivo — no hay datos guardados'
        : '$motivo — datos de las ${textoHora(fecha)}';

    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
