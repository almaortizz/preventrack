import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'confirmacion_pedido_screen.dart';

class ResumenPedidoScreen extends StatefulWidget {
  final Map<String, dynamic> cliente;
  final Map<int, Map<String, dynamic>> carrito;
  final DateTime horaInicio;

  const ResumenPedidoScreen({
    super.key,
    required this.cliente,
    required this.carrito,
    required this.horaInicio,
  });

  @override
  State<ResumenPedidoScreen> createState() => _ResumenPedidoScreenState();
}

class _ResumenPedidoScreenState extends State<ResumenPedidoScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _notasController = TextEditingController();
  late Map<int, Map<String, dynamic>> _carrito;
  bool _isLoading = false;
  double _descuento = 0;

  @override
  void initState() {
    super.initState();
    _carrito = Map.from(widget.carrito);
  }

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  double get _subtotal {
    double total = 0;
    for (var item in _carrito.values) {
      final precio =
          double.tryParse(item['producto']['precio_venta'].toString()) ?? 0;
      total += precio * (item['cantidad'] as int);
    }
    return total;
  }

  double get _total {
    final t = _subtotal - _descuento;
    return t < 0 ? 0 : t;
  }

  int get _totalItems {
    int total = 0;
    for (var item in _carrito.values) {
      total += (item['cantidad'] as int);
    }
    return total;
  }

  void _actualizarCantidad(int id, int delta) {
    setState(() {
      if (_carrito.containsKey(id)) {
        final nuevaCant = (_carrito[id]!['cantidad'] as int) + delta;
        if (nuevaCant <= 0) {
          _carrito.remove(id);
        } else {
          _carrito[id]!['cantidad'] = nuevaCant;
        }
      }
    });
  }

  Future<void> _confirmarPedido() async {
    if (_carrito.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final domicilios = widget.cliente['domicilios'] as List<dynamic>?;
      int? domicilioId;
      if (domicilios != null && domicilios.isNotEmpty) {
        domicilioId = domicilios[0]['id'];
      }

      if (domicilioId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El cliente no tiene domicilio registrado'),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final usuarioId = auth.usuario?['id'];

      final productos = _carrito.values.map((item) {
        return {
          'producto_id': item['producto']['id'],
          'cantidad': item['cantidad'],
          'precio_unitario': item['producto']['precio_venta'],
        };
      }).toList();

      final body = {
        'domicilio_id': domicilioId,
        'preventista_vendedor_id': usuarioId,
        'productos': productos,
        'notas': _notasController.text.isNotEmpty
            ? _notasController.text
            : null,
        'fecha_inicio_creacion': widget.horaInicio.toUtc().toIso8601String(),
        'fecha_fin_creacion': DateTime.now().toUtc().toIso8601String(),
        'descuento': _descuento,
      };

      final result = await _api.post('ventas', body: body);

      if (result['statusCode'] == 201 && mounted) {
        final venta = result['data'];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ConfirmacionPedidoScreen(venta: venta, cliente: widget.cliente),
          ),
        );
      } else {
        if (mounted) {
          final msg = result['data']['message'] ?? 'Error al crear el pedido';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexion. Intenta de nuevo.')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Resumen de Pedido',
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
      body: _carrito.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 56,
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'El carrito esta vacio',
                    style: TextStyle(
                      color: AppColors.textPrimary.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Articulos (${_carrito.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Revisar cantidades',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        ..._carrito.entries.map(
                          (entry) => _buildItemCard(entry.key, entry.value),
                        ),

                        const SizedBox(height: 16),

                        // Notas
                        const Text(
                          'NOTAS DEL PEDIDO (OPCIONAL)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _notasController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText:
                                'Ej: Entregar antes de las 10:00 AM o dejar en recepcion...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.35,
                              ),
                            ),
                            filled: true,
                            fillColor: AppColors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.cardBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.cardBorder,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Descuento
                        const Text(
                          'DESCUENTO (OPCIONAL)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              _descuento = double.tryParse(value) ?? 0;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixText: '\$ ',
                            filled: true,
                            fillColor: AppColors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.cardBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.cardBorder,
                              ),
                            ),
                          ),
                        ),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Subtotal',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '\$${_subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              if (_descuento > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Descuento',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.success.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '-\$${_descuento.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),
                              Container(
                                height: 1,
                                color: AppColors.cardBorder.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '\$${_total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
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

                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _confirmarPedido,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: AppColors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline,
                                  size: 20,
                                ),
                          label: Text(_isLoading ? '' : 'Confirmar Pedido'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Seguir Comprando'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
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
            ),
    );
  }

  Widget _buildItemCard(int id, Map<String, dynamic> item) {
    final producto = item['producto'];
    final nombre = producto['nombre'] ?? '';
    final codigo = producto['codigo'] ?? '';
    final precio = double.tryParse(producto['precio_venta'].toString()) ?? 0;
    final cantidad = item['cantidad'] as int;
    final subtotal = precio * cantidad;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textPrimary.withValues(alpha: 0.25),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'SKU: $codigo',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${precio.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildBotonCantidad(
                    Icons.remove,
                    () => _actualizarCantidad(id, -1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '$cantidad',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildBotonCantidad(
                    Icons.add,
                    () => _actualizarCantidad(id, 1),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotonCantidad(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}
