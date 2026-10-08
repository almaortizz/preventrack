import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../services/print_service.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'catalogo_productos_screen.dart';

class ConfirmacionPedidoScreen extends StatelessWidget {
  final Map<String, dynamic> venta;
  final Map<String, dynamic> cliente;
  final OrigenPedido origen;

  const ConfirmacionPedidoScreen({
    super.key,
    required this.venta,
    required this.cliente,
    required this.origen,
  });

  @override
  Widget build(BuildContext context) {
    final numeroOrden = (venta['numero_orden'] ?? 'N/A').toString();
    final fechaHoy = DateFormat(
      "d 'de' MMMM 'de' yyyy",
      'es',
    ).format(DateTime.now());
    final nombreCliente =
        cliente['nombre_negocio'] ?? cliente['nombre'] ?? 'Cliente';

    // El "atrás" de Android regresa al origen igual que el botón, para no
    // volver al resumen y duplicar el pedido
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) CatalogoProductosScreen.volverAlOrigen(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // Icono check
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: AppColors.white,
                            size: 44,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Titulo
                      const Text(
                        '¡Pedido registrado!',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tu solicitud ha sido procesada\nexitosamente en el sistema Preventrack.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary.withValues(alpha: 0.55),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Card NÚMERO DE ORDEN
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'NÚMERO DE ORDEN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.45,
                                ),
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              numeroOrden.length > 15
                                  ? numeroOrden.substring(0, 15)
                                  : numeroOrden,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 1,
                              color: AppColors.cardBorder.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Fecha',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textPrimary.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      fechaHoy,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Estado',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textPrimary.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.success,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Validado',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Boton Imprimir Ticket
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final auth = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            );
                            final nombre =
                                auth.usuario?['nombre'] ?? 'Preventista';

                            // Completar domicilio.cliente si la API no lo devolvió
                            final ventaTicket = Map<String, dynamic>.from(
                              venta,
                            );
                            final domicilio = Map<String, dynamic>.from(
                              ventaTicket['domicilio'] ?? {},
                            );
                            domicilio['cliente'] ??= cliente;
                            ventaTicket['domicilio'] = domicilio;

                            await PrintService.mostrarDialogoImpresora(
                              context,
                              venta: ventaTicket,
                              preventistaNombre: nombre,
                            );
                          },
                          icon: const Icon(Icons.print_outlined, size: 20),
                          label: const Text('Imprimir Ticket'),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Boton Volver (según la pantalla donde empezó el pedido)
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              CatalogoProductosScreen.volverAlOrigen(context),
                          icon: Icon(origen.icono, size: 18),
                          label: Text(origen.textoRegreso),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Info cliente y entrega
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Cliente',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textPrimary
                                              .withValues(alpha: 0.45),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    nombreCliente,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: AppColors.cardBorder,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.local_shipping_outlined,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Estado',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textPrimary
                                                .withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Pendiente',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
