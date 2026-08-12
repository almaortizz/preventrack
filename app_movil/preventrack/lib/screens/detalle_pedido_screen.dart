import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';

class DetallePedidoScreen extends StatefulWidget {
  final Map<String, dynamic> pedido;

  const DetallePedidoScreen({super.key, required this.pedido});

  @override
  State<DetallePedidoScreen> createState() => _DetallePedidoScreenState();
}

class _DetallePedidoScreenState extends State<DetallePedidoScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _pedidoDetalle;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    try {
      final result = await _api.get('ventas/${widget.pedido['id']}');
      if (result['statusCode'] == 200) {
        setState(() {
          _pedidoDetalle = result['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = _pedidoDetalle ?? widget.pedido;
    final estado = pedido['estado'] ?? '';
    final numero = pedido['numero_orden'] ?? '';
    final total = pedido['total'] ?? '0';
    final domicilio = pedido['domicilio'];
    final detalle = pedido['detalle'] as List<dynamic>? ?? [];
    final impreso = pedido['impreso'] == true || pedido['impreso'] == 1;

    String fechaStr = '';
    if (pedido['created_at'] != null) {
      try {
        final fecha = DateTime.parse(pedido['created_at']);
        fechaStr = '${fecha.day} de ${_nombreMes(fecha.month)}, ${fecha.year}';
      } catch (_) {}
    }

    String clienteNombre = 'Cliente';
    String clienteDireccion = '';
    if (domicilio != null) {
      clienteNombre = domicilio['referencia'] ?? 'Cliente';
      final calle = domicilio['calle'] ?? '';
      final colonia = domicilio['colonia'] ?? '';
      final ciudad = domicilio['ciudad'] ?? '';
      clienteDireccion = [calle, colonia, ciudad].where((s) => s.toString().isNotEmpty).join(', ');
    }

    // Estados para timeline
    final estados = ['pendiente', 'en_ruta', 'entregado'];
    final estadoIndex = estados.indexOf(estado);

    Color estadoColor;
    String estadoLabel;
    switch (estado) {
      case 'pendiente':
        estadoColor = AppColors.warning;
        estadoLabel = 'Pendiente';
        break;
      case 'en_ruta':
        estadoColor = AppColors.secondary;
        estadoLabel = 'En Ruta';
        break;
      case 'entregado':
        estadoColor = AppColors.success;
        estadoLabel = 'Entregado';
        break;
      case 'cancelado':
        estadoColor = AppColors.error;
        estadoLabel = 'Cancelado';
        break;
      default:
        estadoColor = Colors.grey;
        estadoLabel = estado;
    }

    final numeroCorto = numero.length > 15 ? 'ORDEN #${numero.substring(4, 14)}' : 'ORDEN #$numero';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Detalle de Pedido',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
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
          child: Container(color: AppColors.cardBorder.withValues(alpha: 0.5), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: orden + estado
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        numeroCorto,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                      ),
                                      if (fechaStr.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            fechaStr,
                                            style: TextStyle(fontSize: 12, color: AppColors.textPrimary.withValues(alpha: 0.45)),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: estadoColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: estadoColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      estadoLabel,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: estadoColor),
                                    ),
                                  ),
                                ],
                              ),
                              if (estado != 'cancelado') ...[
                                const SizedBox(height: 16),
                                // Timeline
                                _buildTimeline(estadoIndex),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Info cliente
                        const Text(
                          'Informacion del Cliente',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.store, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      clienteNombre,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    ),
                                    if (clienteDireccion.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          clienteDireccion,
                                          style: TextStyle(fontSize: 12, color: AppColors.textPrimary.withValues(alpha: 0.5)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Articulos
                        const Text(
                          'Articulos del Pedido',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 10),

                        if (detalle.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Text(
                              'Sin detalle de productos',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.45)),
                            ),
                          )
                        else
                          ...detalle.map((item) => _buildArticuloCard(item)),

                        const SizedBox(height: 16),

                        // Totales
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Subtotal', style: TextStyle(fontSize: 14, color: AppColors.textPrimary.withValues(alpha: 0.6))),
                                  Text('\$$total', style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(height: 1, color: AppColors.cardBorder.withValues(alpha: 0.5)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  Text('\$$total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Boton imprimir (solo si pendiente y no impreso)
                if (estado == 'pendiente' && !impreso)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border(top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.5))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Funcion de impresion Bluetooth proximamente')),
                          );
                        },
                        icon: const Icon(Icons.print_outlined, size: 20),
                        label: const Text('Imprimir ticket'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildTimeline(int estadoActual) {
    final labels = ['Pendiente', 'En ruta', 'Entregado'];

    return Row(
      children: List.generate(3, (index) {
        final isActive = index <= estadoActual;
        final isCurrent = index == estadoActual;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (index > 0)
                    Expanded(
                      child: Container(
                        height: 3,
                        color: isActive ? AppColors.primary : AppColors.cardBorder,
                      ),
                    ),
                  Container(
                    width: isCurrent ? 28 : 22,
                    height: isCurrent ? 28 : 22,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : AppColors.cardBorder,
                      shape: BoxShape.circle,
                    ),
                    child: isActive
                        ? Icon(Icons.check, color: AppColors.white, size: isCurrent ? 16 : 12)
                        : null,
                  ),
                  if (index < 2)
                    Expanded(
                      child: Container(
                        height: 3,
                        color: index < estadoActual ? AppColors.primary : AppColors.cardBorder,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                labels[index],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppColors.primary : AppColors.textPrimary.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildArticuloCard(Map<String, dynamic> item) {
    final producto = item['producto'];
    final nombre = producto != null ? (producto['nombre'] ?? 'Producto') : 'Producto';
    final cantidad = item['cantidad'] ?? 0;
    final subtotal = item['subtotal'] ?? '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2_outlined, color: AppColors.textPrimary.withValues(alpha: 0.25), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$cantidad Unidades',
                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary.withValues(alpha: 0.45)),
                ),
              ],
            ),
          ),
          Text(
            '\$$subtotal',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  String _nombreMes(int mes) {
    const meses = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return meses[mes];
  }
}
