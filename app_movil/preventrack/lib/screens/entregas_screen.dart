import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import 'detalle_entrega_screen.dart';

class EntregasScreen extends StatefulWidget {
  const EntregasScreen({super.key});

  @override
  State<EntregasScreen> createState() => _EntregasScreenState();
}

class _EntregasScreenState extends State<EntregasScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _entregas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarEntregas();
  }

  Future<void> _cargarEntregas() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.get('ventas?estado=en_ruta');
      if (result['statusCode'] == 200) {
        final data = result['data'];
        setState(() {
          _entregas = data is List ? data : (data['data'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        : _entregas.isEmpty
        ? _buildEmptyState()
        : RefreshIndicator(
            onRefresh: _cargarEntregas,
            color: AppColors.primary,
            child: Column(
              children: [
                // Banner con cantidad
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: AppColors.secondary.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_shipping,
                          color: AppColors.secondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_entregas.length} pedido${_entregas.length == 1 ? '' : 's'} en ruta',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _entregas.length,
                    itemBuilder: (context, index) {
                      return _buildEntregaCard(_entregas[index]);
                    },
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildEntregaCard(Map<String, dynamic> entrega) {
    final numero = entrega['numero_orden'] ?? '';
    final total = entrega['total'] ?? '0';

    // Nombre del cliente
    String clienteNombre = 'Cliente';
    String direccion = 'Sin dirección';
    final domicilio = entrega['domicilio'];
    if (domicilio != null) {
      direccion = domicilio['direccion'] ?? 'Sin dirección';
      final cliente = domicilio['cliente'];
      if (cliente != null) {
        clienteNombre = cliente['nombre_negocio'] ?? 'Cliente';
      }
    }

    final numeroCorto = numero.length > 15
        ? '#${numero.substring(4, 14)}'
        : '#$numero';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleEntregaScreen(ventaId: entrega['id']),
          ),
        );
        // Recargar al volver (por si marcó como entregado)
        _cargarEntregas();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            // Ícono de entrega
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: AppColors.secondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clienteNombre,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.textPrimary.withValues(alpha: 0.35),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          direccion,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary.withValues(alpha: 0.5),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        numeroCorto,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textPrimary.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$$total',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Botón entregar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Entregar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppColors.success.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No hay entregas pendientes',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Los pedidos en ruta aparecerán aquí',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
