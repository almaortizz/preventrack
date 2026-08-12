import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDashboard();
  }

  Future<void> _cargarDashboard() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.get('dashboard');
      if (result['statusCode'] == 200) {
        setState(() {
          _dashboardData = result['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final nombre = auth.usuario?['nombre'] ?? 'Usuario';
    final now = DateTime.now();
    final diaSemana = DateFormat('EEEE', 'es').format(now);
    final fecha = DateFormat("d 'de' MMMM 'de' yyyy", 'es').format(now);
    final fechaCompleta =
        '${diaSemana[0].toUpperCase()}${diaSemana.substring(1)}, $fecha';

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final contadores = _dashboardData?['contadores'] ?? {};
    final ventas = _dashboardData?['ventas'] ?? {};
    final ultimosPedidos = _dashboardData?['ultimos_pedidos'] ?? [];
    final pendientes = contadores['pendientes'] ?? 0;
    final enRuta = contadores['en_ruta'] ?? 0;
    final entregadosHoy = contadores['entregados_hoy'] ?? 0;
    final totalHoy = ventas['total_hoy'] ?? 0;
    final totalEntregas = pendientes + enRuta;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _cargarDashboard,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buen dia, $nombre',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fechaCompleta,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.attach_money,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Ventas de hoy',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${_formatMonto(totalHoy)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.local_shipping_outlined,
                                color: AppColors.secondary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Entregas',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$totalEntregas',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text(
                                    'pendientes',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$enRuta en ruta',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildProgresoDelDia(pendientes, enRuta, entregadosHoy),
                const SizedBox(height: 20),
                _buildUltimosPedidos(ultimosPedidos),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () {},
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: AppColors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildProgresoDelDia(int pendientes, int enRuta, int entregados) {
    final total = pendientes + enRuta + entregados;
    final progreso = total > 0 ? entregados / total : 0.0;

    return Container(
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
              const Text(
                'Progreso del dia',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${(progreso * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (entregados > 0)
                    Expanded(
                      flex: entregados,
                      child: Container(color: AppColors.success),
                    ),
                  if (enRuta > 0)
                    Expanded(
                      flex: enRuta,
                      child: Container(color: AppColors.secondary),
                    ),
                  if (pendientes > 0)
                    Expanded(
                      flex: pendientes,
                      child: Container(color: AppColors.warning),
                    ),
                  if (total == 0)
                    Expanded(child: Container(color: AppColors.cardBorder)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildLeyenda('ENTREGADO', AppColors.success),
              const SizedBox(width: 16),
              _buildLeyenda('EN RUTA', AppColors.secondary),
              const SizedBox(width: 16),
              _buildLeyenda('PENDIENTE', AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeyenda(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildUltimosPedidos(List<dynamic> pedidos) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ultimos pedidos',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'Ver todos',
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
        if (pedidos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 40,
                  color: AppColors.textPrimary.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 8),
                Text(
                  'No hay pedidos recientes',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          )
        else
          ...pedidos.take(5).map((pedido) => _buildPedidoCard(pedido)),
      ],
    );
  }

  Widget _buildPedidoCard(Map<String, dynamic> pedido) {
    final estado = pedido['estado'] ?? '';
    final total = pedido['total'] ?? '0';
    final numero = pedido['numero_orden'] ?? '';
    final domicilio = pedido['domicilio'];
    final vendedor = pedido['vendedor'];
    final clienteNombre = domicilio != null
        ? (domicilio['referencia'] ?? 'Cliente')
        : (vendedor != null ? vendedor['nombre'] ?? 'Cliente' : 'Cliente');

    Color estadoColor;
    String estadoLabel;
    switch (estado) {
      case 'pendiente':
        estadoColor = AppColors.warning;
        estadoLabel = 'PENDIENTE';
        break;
      case 'en_ruta':
        estadoColor = AppColors.secondary;
        estadoLabel = 'EN RUTA';
        break;
      case 'entregado':
        estadoColor = AppColors.success;
        estadoLabel = 'ENTREGADO';
        break;
      case 'cancelado':
        estadoColor = AppColors.error;
        estadoLabel = 'CANCELADO';
        break;
      default:
        estadoColor = Colors.grey;
        estadoLabel = estado.toUpperCase();
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      numeroCorto,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: estadoColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        estadoLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: estadoColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  clienteNombre,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$$total',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            color: AppColors.textPrimary.withValues(alpha: 0.25),
            size: 20,
          ),
        ],
      ),
    );
  }

  String _formatMonto(dynamic monto) {
    final numero = double.tryParse(monto.toString()) ?? 0;
    return NumberFormat('#,##0.00').format(numero);
  }
}
