import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';

class DetalleClienteScreen extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const DetalleClienteScreen({super.key, required this.cliente});

  @override
  State<DetalleClienteScreen> createState() => _DetalleClienteScreenState();
}

class _DetalleClienteScreenState extends State<DetalleClienteScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _pedidos = [];
  bool _isLoadingPedidos = true;

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
  }

  Future<void> _cargarPedidos() async {
    try {
      final result = await _api.get('ventas');
      if (result['statusCode'] == 200) {
        final data = result['data'];
        final todas = data is List ? data : (data['data'] ?? []);
        setState(() {
          _pedidos = todas.take(5).toList();
          _isLoadingPedidos = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingPedidos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cliente = widget.cliente;
    final nombre =
        cliente['nombre_negocio'] ?? cliente['nombre'] ?? 'Sin nombre';
    final codigo = cliente['codigo'] ?? 'N/A';
    final telefono = cliente['telefono'] ?? 'Sin telefono';
    final domicilios = cliente['domicilios'] as List<dynamic>?;
    String direccion = 'Sin direccion';
    if (domicilios != null && domicilios.isNotEmpty) {
      final dom = domicilios[0];
      final calle = dom['calle'] ?? '';
      final colonia = dom['colonia'] ?? '';
      final ciudad = dom['ciudad'] ?? '';
      direccion = [
        calle,
        colonia,
        ciudad,
      ].where((s) => s.isNotEmpty).join(', ');
      if (direccion.isEmpty) direccion = 'Sin direccion';
    }

    final inicial = nombre[0].toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Detalle del Cliente',
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.secondary,
              child: Text(
                inicial,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.cardBorder.withValues(alpha: 0.5),
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card info principal
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NEGOCIO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  nombre,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.store,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ID: #$codigo',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Telefono
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
                        Icon(
                          Icons.phone_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Telefono',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              telefono,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Direccion
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Direccion Completa',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textPrimary.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                direccion,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Historial de pedidos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Historial de pedidos',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'Ver todo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_isLoadingPedidos)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else if (_pedidos.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 36,
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sin pedidos recientes',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._pedidos.map((pedido) => _buildPedidoCard(pedido)),
                ],
              ),
            ),
          ),

          // Boton Nuevo Pedido fijo abajo
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
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: navegar a nuevo pedido
                },
                icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                label: const Text('Nuevo Pedido'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPedidoCard(Map<String, dynamic> pedido) {
    final estado = pedido['estado'] ?? '';
    final total = pedido['total'] ?? '0';
    final numero = pedido['numero_orden'] ?? '';

    Color estadoColor;
    String estadoLabel;
    IconData estadoIcono;
    switch (estado) {
      case 'pendiente':
        estadoColor = AppColors.warning;
        estadoLabel = 'Pendiente';
        estadoIcono = Icons.schedule;
        break;
      case 'en_ruta':
        estadoColor = AppColors.secondary;
        estadoLabel = 'En ruta';
        estadoIcono = Icons.local_shipping;
        break;
      case 'entregado':
        estadoColor = AppColors.success;
        estadoLabel = 'Entregado';
        estadoIcono = Icons.check_circle;
        break;
      case 'cancelado':
        estadoColor = AppColors.error;
        estadoLabel = 'Cancelado';
        estadoIcono = Icons.cancel;
        break;
      default:
        estadoColor = Colors.grey;
        estadoLabel = estado;
        estadoIcono = Icons.receipt;
    }

    final numeroCorto = numero.length > 12
        ? '#${numero.substring(0, 12)}'
        : '#$numero';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(estadoIcono, color: estadoColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  numeroCorto,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
                '\$$total',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                estadoLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: estadoColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
