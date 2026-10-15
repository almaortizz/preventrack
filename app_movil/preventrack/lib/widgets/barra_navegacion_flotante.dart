import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class SeccionNavegacion {
  final IconData icono;
  final IconData iconoActivo;
  final String nombre;

  const SeccionNavegacion(this.icono, this.iconoActivo, this.nombre);
}

// Barra de navegación inferior flotante (cápsula). La sección activa muestra
// ícono y nombre en una pastilla azul; las demás, solo el ícono (su nombre
// aparece al mantenerlo presionado y lo leen los lectores de pantalla).
class BarraNavegacionFlotante extends StatelessWidget {
  final int indice;
  final ValueChanged<int> onCambio;
  final List<SeccionNavegacion> secciones;

  const BarraNavegacionFlotante({
    super.key,
    required this.indice,
    required this.onCambio,
    required this.secciones,
  });

  @override
  Widget build(BuildContext context) {
    // SafeArea: no encimarse con la barra de gestos de Android
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < secciones.length; i++)
                _Boton(
                  seccion: secciones[i],
                  activo: i == indice,
                  onTap: () => onCambio(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Boton extends StatelessWidget {
  final SeccionNavegacion seccion;
  final bool activo;
  final VoidCallback onTap;

  const _Boton({
    required this.seccion,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final boton = Semantics(
      button: true,
      selected: activo,
      label: seccion.nombre,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: activo ? 16 : 14),
          decoration: BoxDecoration(
            color: activo ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  activo ? seccion.iconoActivo : seccion.icono,
                  size: 24,
                  color: activo
                      ? Colors.white
                      : AppColors.textPrimary.withValues(alpha: 0.55),
                ),
                if (activo) ...[
                  const SizedBox(width: 8),
                  Text(
                    seccion.nombre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // Sin nombre visible: se muestra al mantener presionado
    return activo ? boton : Tooltip(message: seccion.nombre, child: boton);
  }
}
