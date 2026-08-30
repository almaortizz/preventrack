import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({super.key});

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDashboard();
  }

  Future<void> _cargarDashboard() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.get('dashboard-admin');
      if (result['statusCode'] == 200) {
        setState(() {
          _data = result['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final nombre = auth.usuario?['nombre'] ?? 'Administrador';
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

    if (_data == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.textPrimary.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el dashboard',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _cargarDashboard,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      );
    }

    final ventasHoy = _data!['ventas_hoy'] ?? {};
    final ventasSemana = _data!['ventas_semana'] ?? {};
    final entregas = _data!['entregas'] ?? {};
    final equipo = _data!['equipo'] ?? {};
    final cuota = _data!['cuota'] ?? {};
    final ultimosPedidos = _data!['ultimos_pedidos'] ?? [];
    final alertasFraude = _data!['alertas_fraude'] ?? 0;

    return RefreshIndicator(
      onRefresh: _cargarDashboard,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Saludo ──
            Text(
              'Hola, $nombre',
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

            // ── Alerta anti-fraude (solo si hay) ──
            if (alertasFraude > 0) ...[
              _buildAlertaFraude(alertasFraude),
              const SizedBox(height: 12),
            ],

            // ── Ventas hoy + Ventas semana ──
            Row(
              children: [
                Expanded(
                  child: _buildTarjetaIndicador(
                    icono: Icons.attach_money,
                    iconoColor: AppColors.primary,
                    titulo: 'Ventas hoy',
                    valor: '\$${_formatMonto(ventasHoy['total'] ?? 0)}',
                    detalle: '${ventasHoy['cantidad'] ?? 0} pedidos',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTarjetaIndicador(
                    icono: Icons.calendar_month_outlined,
                    iconoColor: AppColors.secondary,
                    titulo: 'Ventas semana',
                    valor: '\$${_formatMonto(ventasSemana['total'] ?? 0)}',
                    detalle: '${ventasSemana['cantidad'] ?? 0} pedidos',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Equipo + Entregas ──
            Row(
              children: [
                Expanded(
                  child: _buildTarjetaIndicador(
                    icono: Icons.people_outline,
                    iconoColor: AppColors.success,
                    titulo: 'Equipo activo',
                    valor: '${equipo['preventistas_activos'] ?? 0}',
                    detalle: 'de ${equipo['total_preventistas'] ?? 0} preventistas',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTarjetaIndicador(
                    icono: Icons.local_shipping_outlined,
                    iconoColor: AppColors.warning,
                    titulo: 'Entregas hoy',
                    valor: '${entregas['completadas'] ?? 0}',
                    detalle: '${entregas['pendientes'] ?? 0} pendientes',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Cumplimiento de cuota ──
            _buildCuotaEquipo(cuota),
            const SizedBox(height: 16),

            // ── Ranking de preventistas ──
            _buildRankingPreventistas(cuota['detalle'] ?? []),
            const SizedBox(height: 20),

            // ── Últimos pedidos ──
            _buildUltimosPedidos(ultimosPedidos),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  WIDGETS AUXILIARES
  // ─────────────────────────────────────────────

  Widget _buildAlertaFraude(int cantidad) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alerta anti-fraude',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$cantidad pedido${cantidad == 1 ? '' : 's'} creado${cantidad == 1 ? '' : 's'} en menos de 30 seg',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.error.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AppColors.error.withValues(alpha: 0.4),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaIndicador({
    required IconData icono,
    required Color iconoColor,
    required String titulo,
    required String valor,
    required String detalle,
  }) {
    return Container(
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
              color: iconoColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: iconoColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detalle,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuotaEquipo(Map<String, dynamic> cuota) {
    final objetivo = cuota['objetivo'] ?? 6500;
    final cumplen = cuota['cumplen'] ?? 0;
    final noCumplen = cuota['no_cumplen'] ?? 0;
    final total = cumplen + noCumplen;
    final porcentajeCumple = total > 0 ? (cumplen / total * 100).toInt() : 0;

    return Container(
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
              const Text(
                'Cumplimiento de cuota',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Meta: \$${_formatMonto(objetivo)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Barra de cumplimiento del equipo
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (cumplen > 0)
                    Expanded(
                      flex: cumplen,
                      child: Container(color: AppColors.success),
                    ),
                  if (noCumplen > 0)
                    Expanded(
                      flex: noCumplen,
                      child: Container(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                  if (total == 0)
                    Expanded(child: Container(color: AppColors.cardBorder)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildLeyendaCuota(
                '$cumplen cumplen',
                AppColors.success,
              ),
              const SizedBox(width: 20),
              _buildLeyendaCuota(
                '$noCumplen pendientes',
                AppColors.error,
              ),
              const Spacer(),
              Text(
                '$porcentajeCumple%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeyendaCuota(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingPreventistas(List<dynamic> detalle) {
    if (detalle.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rendimiento del equipo',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...detalle.map((prev) => _buildPreventistaCard(prev)),
      ],
    );
  }

  Widget _buildPreventistaCard(Map<String, dynamic> prev) {
    final nombre = prev['nombre'] ?? 'Sin nombre';
    final ventaSemanal = prev['venta_semanal'] ?? 0;
    final objetivo = prev['objetivo'] ?? 6500;
    final porcentaje = (prev['porcentaje'] as num?)?.toDouble() ?? 0;
    final cumple = prev['cumple'] == true;
    final progreso = porcentaje / 100;
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cumple
              ? AppColors.success.withValues(alpha: 0.25)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          // Avatar con inicial
          CircleAvatar(
            radius: 18,
            backgroundColor: cumple
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.08),
            child: Text(
              inicial,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cumple ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cumple
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${porcentaje.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cumple ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Barra de progreso individual
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progreso > 1 ? 1 : progreso,
                    minHeight: 6,
                    backgroundColor: AppColors.cardBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      cumple ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${_formatMonto(ventaSemanal)} de \$${_formatMonto(objetivo)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUltimosPedidos(List<dynamic> pedidos) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Últimos pedidos',
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
          ...pedidos.take(10).map((pedido) => _buildPedidoCard(pedido)),
      ],
    );
  }

  Widget _buildPedidoCard(Map<String, dynamic> pedido) {
    final estado = pedido['estado'] ?? '';
    final total = pedido['total'] ?? '0';
    final folio = pedido['folio'] ?? '';
    final preventista = pedido['preventista'] ?? '';
    final cliente = pedido['cliente'] ?? '';
    final fecha = pedido['fecha'] ?? '';

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
      case 'no_entregado':
        estadoColor = AppColors.error;
        estadoLabel = 'NO ENTREGADO';
        break;
      case 'cancelado':
        estadoColor = AppColors.error;
        estadoLabel = 'CANCELADO';
        break;
      default:
        estadoColor = Colors.grey;
        estadoLabel = estado.toUpperCase();
    }

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
                      folio,
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
                  cliente,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: AppColors.textPrimary.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        preventista,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textPrimary.withValues(alpha: 0.4),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      fecha,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '\$${_formatMonto(total)}',
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
