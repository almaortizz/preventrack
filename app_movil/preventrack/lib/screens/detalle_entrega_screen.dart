import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';

class DetalleEntregaScreen extends StatefulWidget {
  final int ventaId;

  const DetalleEntregaScreen({super.key, required this.ventaId});

  @override
  State<DetalleEntregaScreen> createState() => _DetalleEntregaScreenState();
}

class _DetalleEntregaScreenState extends State<DetalleEntregaScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _venta;
  bool _isLoading = true;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.get('ventas/${widget.ventaId}');
      if (result['statusCode'] == 200) {
        setState(() {
          _venta = result['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _marcarEntregado() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar entrega'),
        content: const Text('¿Confirmas que el pedido fue entregado al cliente?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sí, entregar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _procesando = true);
    try {
      final result = await _api.post('ventas/${widget.ventaId}/marcar-entregado');
      if (!mounted) return;

      if (result['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido entregado correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      } else {
        final msg = result['data']?['message'] ?? 'Error al marcar entrega';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
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
    if (mounted) setState(() => _procesando = false);
  }

  Future<void> _marcarNoEntregado() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No entregado'),
        content: const Text(
          '¿El pedido no pudo ser entregado? Regresará a estado pendiente para reprogramar.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('No entregado'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _procesando = true);
    try {
      final result = await _api.post('ventas/${widget.ventaId}/marcar-no-entregado');
      if (!mounted) return;

      if (result['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido regresado a pendiente'),
            backgroundColor: AppColors.warning,
          ),
        );
        Navigator.pop(context);
      } else {
        final msg = result['data']?['message'] ?? 'Error al actualizar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
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
    if (mounted) setState(() => _procesando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Detalle de Entrega',
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _venta == null
              ? const Center(child: Text('No se pudo cargar el pedido'))
              : _buildContenido(),
    );
  }

  Widget _buildContenido() {
    // Datos del cliente
    String clienteNombre = 'Cliente';
    String direccion = 'Sin dirección';
    String telefono = '';
    final domicilio = _venta!['domicilio'];
    if (domicilio != null) {
      direccion = domicilio['direccion'] ?? 'Sin dirección';
      final cliente = domicilio['cliente'];
      if (cliente != null) {
        clienteNombre = cliente['nombre_negocio'] ?? 'Cliente';
        telefono = cliente['telefono'] ?? '';
      }
    }

    final total = _venta!['total'] ?? '0';
    final descuento = _venta!['descuento'] ?? '0';
    final numero = _venta!['numero_orden'] ?? '';
    final productos = _venta!['detalle'] as List<dynamic>? ?? [];
    final estado = _venta!['estado'] ?? '';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info del cliente
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.store_outlined,
                              color: AppColors.secondary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  clienteNombre,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  numero,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary.withValues(alpha: 0.45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Dirección
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.textPrimary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              direccion,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (telefono.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 16,
                              color: AppColors.textPrimary.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              telefono,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Productos
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Productos (${productos.length})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (productos.isEmpty)
                        Text(
                          'Sin detalle de productos',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary.withValues(alpha: 0.45),
                          ),
                        )
                      else
                        ...productos.map((item) {
                          final producto = item['producto'];
                          final nombre = producto != null
                              ? (producto['nombre'] ?? 'Producto')
                              : 'Producto';
                          final cantidad = item['cantidad'] ?? 0;
                          final precioUnitario = item['precio_unitario'] ?? '0';
                          final subtotal = item['subtotal'] ?? '0';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombre,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '$cantidad x \$$precioUnitario',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textPrimary.withValues(alpha: 0.45),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\$$subtotal',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const Divider(height: 16),
                      // Descuento (si aplica)
                      if (double.tryParse(descuento.toString()) != null &&
                          double.parse(descuento.toString()) > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Descuento',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary.withValues(alpha: 0.5),
                              ),
                            ),
                            Text(
                              '-\$$descuento',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '\$$total',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Botones de acción (solo si está en_ruta)
        if (estado == 'en_ruta')
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
            child: Column(
              children: [
                // Botón Registrar Entrega
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _procesando ? null : _marcarEntregado,
                    icon: _procesando
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
                      _procesando ? 'Procesando...' : 'Registrar Entrega',
                      style: const TextStyle(
                        fontSize: 15,
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
                const SizedBox(height: 10),
                // Botón Marcar No Entregado
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _procesando ? null : _marcarNoEntregado,
                    icon: const Icon(Icons.cancel_outlined, size: 20),
                    label: const Text(
                      'Marcar No Entregado',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
