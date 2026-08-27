import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import 'detalle_cliente_screen.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _buscarController = TextEditingController();
  List<dynamic> _clientes = [];
  bool _isLoading = true;
  String _filtroActual = 'Todos';
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  Future<void> _cargarClientes() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.get('clientes');
      if (result['statusCode'] == 200) {
        final data = result['data'];
        setState(() {
          _clientes = data is List ? data : (data['data'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _clientesFiltrados {
    List<dynamic> resultado = _clientes;

    // Filtro por chip (Todos / Activos)
    if (_filtroActual == 'Activos') {
      resultado = resultado.where((c) => c['estado'] == 'activo').toList();
    }

    // Filtro por búsqueda (nombre, folio, dirección)
    if (_busqueda.isNotEmpty) {
      final query = _busqueda.toLowerCase();
      resultado = resultado.where((c) {
        final nombre = (c['nombre_negocio'] ?? '').toString().toLowerCase();
        final folio = (c['folio'] ?? '').toString().toLowerCase();
        final propietario = (c['propietario'] ?? '').toString().toLowerCase();

        // Buscar también en domicilios
        String direccion = '';
        final domicilios = c['domicilios'] as List<dynamic>?;
        if (domicilios != null && domicilios.isNotEmpty) {
          direccion = (domicilios[0]['direccion'] ?? '').toString().toLowerCase();
        }

        return nombre.contains(query) ||
            folio.contains(query) ||
            propietario.contains(query) ||
            direccion.contains(query);
      }).toList();
    }

    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    final clientesFiltrados = _clientesFiltrados;

    return Stack(
      children: [
        Column(
          children: [
            // Barra de búsqueda
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: AppColors.white,
              child: TextField(
                controller: _buscarController,
                onChanged: (value) {
                  setState(() => _busqueda = value);
                },
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, ID o dirección',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary.withValues(alpha: 0.4),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.primary,
                  ),
                  suffixIcon: _busqueda.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: AppColors.textPrimary.withValues(alpha: 0.4),
                          ),
                          onPressed: () {
                            _buscarController.clear();
                            setState(() => _busqueda = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Filtros
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              color: AppColors.white,
              child: Row(
                children: [
                  _buildFiltroChip('Todos', _filtroActual == 'Todos'),
                  const SizedBox(width: 8),
                  _buildFiltroChip('Activos', _filtroActual == 'Activos'),
                ],
              ),
            ),

            Container(
              height: 1,
              color: AppColors.cardBorder.withValues(alpha: 0.5),
            ),

            // Contador
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BASE DE DATOS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${clientesFiltrados.length} Clientes Registrados',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.tune,
                    size: 20,
                    color: AppColors.textPrimary.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),

            // Lista
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : clientesFiltrados.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _cargarClientes,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                            itemCount: clientesFiltrados.length,
                            itemBuilder: (context, index) {
                              return _buildClienteCard(clientesFiltrados[index]);
                            },
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
              // TODO: Navegar a pantalla de crear cliente
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Crear cliente — próximamente'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.person_add, color: AppColors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltroChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() => _filtroActual = label);
      },
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
            fontWeight: FontWeight.w500,
            color: isSelected
                ? AppColors.white
                : AppColors.textPrimary.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildClienteCard(Map<String, dynamic> cliente) {
    final nombre =
        cliente['nombre_negocio'] ?? cliente['nombre'] ?? 'Sin nombre';
    final folio = cliente['folio'] ?? 'N/A';
    final domicilios = cliente['domicilios'] as List<dynamic>?;
    String direccion = 'Sin dirección';
    if (domicilios != null && domicilios.isNotEmpty) {
      direccion = domicilios[0]['direccion'] ?? 'Sin dirección';
    }

    final estado = cliente['estado'] ?? 'activo';

    final palabras = nombre.split(' ');
    String iniciales;
    if (palabras.length >= 2) {
      iniciales = '${palabras[0][0]}${palabras[1][0]}'.toUpperCase();
    } else {
      iniciales =
          nombre.substring(0, nombre.length >= 2 ? 2 : 1).toUpperCase();
    }

    final colors = [
      AppColors.primary,
      AppColors.secondary,
      const Color(0xFF6B4C9A),
      const Color(0xFF2E7D32),
      const Color(0xFFE65100),
      const Color(0xFF546E7A),
    ];
    final colorIndex = nombre.hashCode.abs() % colors.length;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleClienteScreen(cliente: cliente),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors[colorIndex],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  iniciales,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
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
                    children: [
                      Expanded(
                        child: Text(
                          nombre,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: estado == 'activo'
                                  ? AppColors.success
                                  : AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            estado == 'activo' ? 'Al día' : 'Inactivo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: estado == 'activo'
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: #$folio',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.textPrimary.withValues(alpha: 0.35),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          direccion,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.45,
                            ),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppColors.textPrimary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            _busqueda.isNotEmpty
                ? 'No se encontraron resultados'
                : 'No hay clientes registrados',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}
