import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';

// Envía el ticket del pedido como mensaje de texto por WhatsApp.
// Abre directo el chat del cliente (si tiene teléfono registrado) con el
// mensaje listo; el preventista solo revisa y toca "Enviar". Sin conexión,
// WhatsApp lo envía cuando vuelve la señal.
class WhatsappService {
  static Future<void> enviarTicket(
    BuildContext context, {
    required Map<String, dynamic> venta,
    Map<String, dynamic>? cliente,
    String? preventistaNombre,
  }) async {
    // Cliente: el que pasa la pantalla o el que trae la venta
    final clienteDatos =
        cliente ??
        (venta['domicilio'] is Map
            ? venta['domicilio']['cliente'] as Map<String, dynamic>?
            : null);

    final mensaje = armarMensaje(
      venta,
      clienteNombre: (clienteDatos?['nombre_negocio'] ?? 'Cliente').toString(),
      preventistaNombre: preventistaNombre,
    );
    final telefono = _telefonoWhatsapp(clienteDatos?['telefono']?.toString());

    // Sin teléfono registrado: WhatsApp deja elegir el contacto
    final url = Uri.parse(
      'https://wa.me/${telefono ?? ''}?text=${Uri.encodeComponent(mensaje)}',
    );

    final abierto = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!abierto && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp en este celular.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // Número en formato internacional para WhatsApp (México: 52 + 10 dígitos).
  // Regresa null si no hay un número válido.
  static String? _telefonoWhatsapp(String? telefono) {
    final digitos = (telefono ?? '').replaceAll(RegExp(r'\D'), '');
    if (digitos.length == 10) return '52$digitos';
    if (digitos.length == 12 && digitos.startsWith('52')) return digitos;
    return null;
  }

  static String _dinero(double valor) => '\$${valor.toStringAsFixed(2)}';

  // Mismos datos que el ticket impreso (PrintService)
  static String armarMensaje(
    Map<String, dynamic> venta, {
    required String clienteNombre,
    String? preventistaNombre,
  }) {
    final numeroOrden = (venta['numero_orden'] ?? '').toString();
    final total = double.tryParse(venta['total']?.toString() ?? '0') ?? 0;
    final descuento =
        double.tryParse(venta['descuento']?.toString() ?? '0') ?? 0;
    final detalle = venta['detalle'] as List<dynamic>? ?? [];

    // Fecha y hora del pedido (Laravel envía UTC → hora local)
    String fecha = '';
    final createdAt = venta['created_at']?.toString();
    if (createdAt != null && createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        fecha =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
            '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} '
            '${dt.hour >= 12 ? 'PM' : 'AM'}';
      } catch (_) {}
    }

    final lineas = <String>[
      '*DISTRIBUIDORA BELLA LUZ*',
      'Ticket de pedido',
      '',
      'Remisión: $numeroOrden',
      if (fecha.isNotEmpty) 'Fecha: $fecha',
      'Cliente: $clienteNombre',
      if (preventistaNombre != null && preventistaNombre.isNotEmpty)
        'Atendió: $preventistaNombre',
      '',
      '*Productos*',
    ];

    double subtotal = 0;
    for (final item in detalle) {
      final nombre = (item['producto']?['nombre'] ?? 'Producto').toString();
      final cantidad = num.tryParse(item['cantidad']?.toString() ?? '0') ?? 0;
      final precio =
          double.tryParse(item['precio_unitario']?.toString() ?? '0') ?? 0;
      final importe = (cantidad * precio).toDouble();
      subtotal += importe;
      lineas.add(
        '• $cantidad x $nombre (${_dinero(precio)}) = ${_dinero(importe)}',
      );
    }

    lineas.add('');
    if (descuento > 0) {
      lineas.add('Subtotal: ${_dinero(subtotal)}');
      lineas.add('Descuento: -${_dinero(descuento)}');
    }
    lineas.add('*Total: ${_dinero(total)}*');
    lineas.add('');
    lineas.add('Gracias por su compra.');

    return lineas.join('\n');
  }
}
