import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/aviso_datos_guardados.dart';
import '../widgets/aviso_jornada.dart';
import '../services/api_service.dart';
import 'detalle_pedido_screen.dart';
import 'catalogo_productos_screen.dart';
import '../services/database_service.dart';

class PedidosScreen extends StatefulWidget {
  // Si viene, muestra solo los pedidos de ese cliente (historial completo
  // desde el detalle del cliente), sin el botón de nuevo pedido
  final int? clienteId;

  const PedidosScreen({super.key, this.clienteId});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _pedidos = [];
  bool _isLoading = true;
  String _filtroActual = 'Todos';

  // Mostrando la copia guardada (sin conexión): de qué hora es y por qué
  bool _usandoCopia = false;
  DateTime? _fechaCopia;
  bool _sinConexion = true;

  // Pedidos levantados sin conexión que aún no se suben
  List<Map<String, dynamic>> _enCola = [];

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

  int? get _usuarioId => int.tryParse(
    '${Provider.of<AuthProvider>(context, listen: false).usuario?['id']}',
  );

  // Copia guardada por separado: la lista general y el historial de cada cliente
  String get _claveCopia => widget.clienteId != null
      ? 'pedidos_cliente_${widget.clienteId}'
      : 'pedidos';

  Future<void> _cargarPedidos() async {
    setState(() => _isLoading = true);
    final usuarioId = _usuarioId;

    // Los pedidos por subir solo se muestran en la lista general
    if (widget.clienteId == null) {
      final enCola = await DatabaseService.obtenerPedidosEnCola();
      if (mounted) setState(() => _enCola = enCola);
    }

    var sinConexion = true;
    try {
      // Todas las páginas (la API las entrega de 100 en 100)
      final result = await _api
          .obtenerTodos(
            widget.clienteId != null
                ? 'ventas?cliente_id=${widget.clienteId}'
                : 'ventas',
          )
          .timeout(const Duration(seconds: 30));
      if (result['statusCode'] == 200) {
        final data = result['data'];
        final pedidos = data is List ? data : (data['data'] ?? []);
        await DatabaseService.guardarCopia(_claveCopia, usuarioId, pedidos);
        if (!mounted) return;
        setState(() {
          _pedidos = pedidos;
          _usandoCopia = false;
          _isLoading = false;
        });
        return;
      }
      sinConexion = false; // la API respondió, pero con error
    } catch (e) {
      // Sin conexión
    }

    // Se muestra la última lista guardada en el celular
    final copia = await DatabaseService.obtenerCopia(_claveCopia, usuarioId);
    if (!mounted) return;
    setState(() {
      _pedidos = copia != null
          ? List<dynamic>.from(copia['datos'] as List)
          : [];
      _fechaCopia = copia?['fecha'] as DateTime?;
      _usandoCopia = true;
      _sinConexion = sinConexion;
      _isLoading = false;
    });
  }

  // Los pedidos por subir se ven en "Todos" y en "Pendientes"
  List<Map<String, dynamic>> get _enColaVisibles =>
      _filtroActual == 'Todos' || _filtroActual == 'Pendientes' ? _enCola : [];

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
    // Antes de elegir cliente: el pedido requiere la jornada iniciada
    if (!await requiereJornadaActiva(context)) return;
    if (!mounted) return;

    // Todas las páginas
    final result = await _api.obtenerTodos('clientes');
    if (result['statusCode'] != 200) return;

    final data = result['data'];
    // Solo clientes activos: a los inactivos no se les levantan pedidos
    final clientes = (data is List ? data : (data['data'] ?? []))
        .where((c) => c['estado'] != 'inactivo')
        .toList();

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
                    onTap: () async {
                      Navigator.pop(ctx);
                      final hubo = await CatalogoProductosScreen.abrir(
                        context,
                        cliente: cliente,
                        origen: OrigenPedido.pedidos,
                      );
                      if (hubo == true && mounted) _cargarPedidos();
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
    final enCola = _enColaVisibles;
    final total = enCola.length + pedidosFiltrados.length;

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

            // Sin conexión: lista guardada y de qué hora es
            if (_usandoCopia && !_isLoading)
              AvisoDatosGuardados(
                fecha: _fechaCopia,
                sinConexion: _sinConexion,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              ),

            // Lista
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : total == 0
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
                        // Primero los que faltan por subir, luego los de la API
                        itemCount: total,
                        itemBuilder: (context, index) => index < enCola.length
                            ? _buildPedidoEnCola(enCola[index])
                            : _buildPedidoCard(
                                pedidosFiltrados[index - enCola.length],
                              ),
                      ),
                    ),
            ),
          ],
        ),

        // FAB (no en el historial de un cliente)
        if (widget.clienteId == null)
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

  // Pedido levantado sin conexión que todavía no llega a la oficina
  Widget _buildPedidoEnCola(Map<String, dynamic> pedido) {
    final folio = pedido['numero_orden']?.toString() ?? '';
    final cliente = pedido['cliente_nombre_local']?.toString() ?? 'Cliente';
    final total = double.tryParse(pedido['total_local']?.toString() ?? '') ?? 0;

    String fechaStr = '';
    final fecha = DateTime.tryParse(
      pedido['fecha_fin_creacion']?.toString() ?? '',
    );
    if (fecha != null) {
      fechaStr = DateFormat("d MMM, yyyy HH:mm", 'es').format(fecha.toLocal());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORDEN #$folio',
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
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 13,
                      color: AppColors.warning,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Por enviar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            cliente,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                fechaStr.isNotEmpty ? fechaStr : 'Sin fecha',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Se subirá solo cuando haya conexión',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary.withValues(alpha: 0.45),
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
