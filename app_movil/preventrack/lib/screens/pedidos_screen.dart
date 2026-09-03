import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import 'detalle_pedido_screen.dart';
import 'catalogo_productos_screen.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _pedidos = [];
  bool _isLoading = true;
  String _filtroActual = 'Todos';

  final List<String> _filtros = [
    'Todos',
    'Pendientes',
    'En ruta',
    'Entregados',
    'Cancelados',
  ];

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
  }

  Future<void> _cargarPedidos() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.get('ventas');
      if (result['statusCode'] == 200) {
        final data = result['data'];
        setState(() {
          _pedidos = data is List ? data : (data['data'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _pedidosFiltrados {
    if (_filtroActual == 'Todos') return _pedidos;

    String estado;
    switch (_filtroActual) {
      case 'Pendientes':
        estado = 'pendiente';
        break;
      case 'En ruta':
        estado = 'en_ruta';
        break;
      case 'Entregados':
        estado = 'entregado';
        break;
      case 'Cancelados':
        estado = 'cancelado';
        break;
      default:
        return _pedidos;
    }

    return _pedidos.where((p) => p['estado'] == estado).toList();
  }

  void _mostrarSelectorCliente() async {
    final result = await _api.get('clientes');
    if (result['statusCode'] != 200) return;

    final data = result['data'];
    final clientes = data is List ? data : (data['data'] ?? []);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Seleccionar cliente',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Icon(
                      Icons.close,
                      color: AppColors.textPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: clientes.length,
                itemBuilder: (_, index) {
                  final cliente = clientes[index];
                  final nombre = cliente['nombre_negocio'] ?? 'Sin nombre';
                  final folio = cliente['folio'] ?? '';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        nombre[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(nombre),
                    subtitle: Text('ID: #$folio'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CatalogoProductosScreen(cliente: cliente),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pedidosFiltrados = _pedidosFiltrados;

    return Stack(
      children: [
        Column(
          children: [
            // Filtros
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: AppColors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filtros.map((f) => _buildFiltroChip(f)).toList(),
                ),
              ),
            ),

            Container(
              height: 1,
              color: AppColors.cardBorder.withValues(alpha: 0.5),
            ),

            // Lista
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : pedidosFiltrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 56,
                            color: AppColors.textPrimary.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _filtroActual == 'Todos'
                                ? 'No hay pedidos'
                                : 'No hay pedidos ${_filtroActual.toLowerCase()}',
                            style: TextStyle(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargarPedidos,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: pedidosFiltrados.length,
                        itemBuilder: (context, index) =>
                            _buildPedidoCard(pedidosFiltrados[index]),
                      ),
                    ),
            ),
          ],
        ),

        // FAB
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () {
              _mostrarSelectorCliente();
            },
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: AppColors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltroChip(String label) {
    final isSelected = _filtroActual == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filtroActual = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.cardBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? AppColors.white
                  : AppColors.textPrimary.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPedidoCard(Map<String, dynamic> pedido) {
    final estado = pedido['estado'] ?? '';
    final total = pedido['total'] ?? '0';
    final numero = pedido['numero_orden'] ?? '';

    // Nombre del cliente: domicilio → cliente → nombre_negocio
    String clienteNombre = 'Cliente';
    final domicilio = pedido['domicilio'];
    if (domicilio != null) {
      final cliente = domicilio['cliente'];
      if (cliente != null) {
        clienteNombre = cliente['nombre_negocio'] ?? 'Cliente';
      }
    }

    // Fecha
    String fechaStr = '';
    if (pedido['created_at'] != null) {
      try {
        final fecha = DateTime.parse(pedido['created_at']);
        fechaStr = DateFormat("d MMM, yyyy", 'es').format(fecha);
      } catch (_) {}
    }

    Color estadoColor;
    String estadoLabel;
    switch (estado) {
      case 'pendiente':
        estadoColor = AppColors.warning;
        estadoLabel = 'Pendiente';
        break;
      case 'en_ruta':
        estadoColor = AppColors.secondary;
        estadoLabel = 'En ruta';
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

    final numeroCorto = numero.length > 15
        ? 'ORDEN #${numero.substring(4, 14)}'
        : 'ORDEN #$numero';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetallePedidoScreen(pedido: pedido),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: orden + badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  numeroCorto,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary.withValues(alpha: 0.5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: estadoColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: estadoColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    estadoLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: estadoColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Nombre cliente
            Text(
              clienteNombre,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            // Fecha y total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FECHA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary.withValues(alpha: 0.4),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fechaStr.isNotEmpty ? fechaStr : 'Sin fecha',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary.withValues(alpha: 0.4),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$$total',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
