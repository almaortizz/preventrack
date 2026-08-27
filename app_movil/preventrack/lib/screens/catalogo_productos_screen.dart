import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import 'resumen_pedido_screen.dart';

class CatalogoProductosScreen extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const CatalogoProductosScreen({super.key, required this.cliente});

  @override
  State<CatalogoProductosScreen> createState() =>
      _CatalogoProductosScreenState();
}

class _CatalogoProductosScreenState extends State<CatalogoProductosScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _buscarController = TextEditingController();
  List<dynamic> _productos = [];
  List<dynamic> _categorias = [];
  bool _isLoading = true;
  String _categoriaSeleccionada = 'Todo';
  late DateTime _horaInicio;

  final Map<int, Map<String, dynamic>> _carrito = {};

  @override
  void initState() {
    super.initState();
    _horaInicio = DateTime.now();
    _cargarDatos();
  }

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final resultP = await _api.get('productos');
      final resultC = await _api.get('categorias');

      if (resultP['statusCode'] == 200) {
        final data = resultP['data'];
        _productos = data is List ? data : (data['data'] ?? []);
      }
      if (resultC['statusCode'] == 200) {
        final data = resultC['data'];
        _categorias = data is List ? data : (data['data'] ?? []);
      }
    } catch (e) {}
    setState(() => _isLoading = false);
  }

  List<dynamic> get _productosFiltrados {
    List<dynamic> lista = _productos;

    if (_categoriaSeleccionada != 'Todo') {
      lista = lista.where((p) {
        final cat = p['categoria'];
        if (cat == null) return false;
        final nombreCat = cat['nombre'] ?? '';
        return nombreCat == _categoriaSeleccionada;
      }).toList();
    }

    final query = _buscarController.text.toLowerCase();
    if (query.isNotEmpty) {
      lista = lista.where((p) {
        final nombre = (p['nombre'] ?? '').toString().toLowerCase();
        final codigo = (p['codigo'] ?? '').toString().toLowerCase();
        return nombre.contains(query) || codigo.contains(query);
      }).toList();
    }

    return lista;
  }

  int get _totalItems {
    int total = 0;
    for (var item in _carrito.values) {
      total += (item['cantidad'] as int);
    }
    return total;
  }

  double get _totalEstimado {
    double total = 0;
    for (var item in _carrito.values) {
      final precio =
          double.tryParse(item['producto']['precio_venta'].toString()) ?? 0;
      total += precio * (item['cantidad'] as int);
    }
    return total;
  }

  void _agregarProducto(Map<String, dynamic> producto) {
    final id = producto['id'] as int;
    setState(() {
      if (_carrito.containsKey(id)) {
        _carrito[id]!['cantidad'] = (_carrito[id]!['cantidad'] as int) + 1;
      } else {
        _carrito[id] = {'producto': producto, 'cantidad': 1};
      }
    });
  }

  void _quitarProducto(int id) {
    setState(() {
      if (_carrito.containsKey(id)) {
        final cant = _carrito[id]!['cantidad'] as int;
        if (cant <= 1) {
          _carrito.remove(id);
        } else {
          _carrito[id]!['cantidad'] = cant - 1;
        }
      }
    });
  }

  int _getCantidad(int id) {
    return _carrito.containsKey(id) ? (_carrito[id]!['cantidad'] as int) : 0;
  }

  void _mostrarDialogoCantidad(
    Map<String, dynamic> producto,
    int cantidadActual,
  ) {
    final controller = TextEditingController(text: '$cantidadActual');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          producto['nombre'] ?? 'Producto',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Cantidad',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final nueva = int.tryParse(controller.text) ?? 0;
              final id = producto['id'] as int;
              setState(() {
                if (nueva <= 0) {
                  _carrito.remove(id);
                } else {
                  _carrito[id] = {'producto': producto, 'cantidad': nueva};
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productosFiltrados = _productosFiltrados;
    final hayCarrito = _carrito.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Nuevo Pedido - Productos',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            fontSize: 17,
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
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: AppColors.white,
            child: TextField(
              controller: _buscarController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por SKU, nombre...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary.withValues(alpha: 0.4),
                ),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
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
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            color: AppColors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoriaChip('Todo'),
                  ..._categorias.map(
                    (c) => _buildCategoriaChip(c['nombre'] ?? ''),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 1,
            color: AppColors.cardBorder.withValues(alpha: 0.5),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : productosFiltrados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 56,
                          color: AppColors.textPrimary.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No hay productos',
                          style: TextStyle(
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: productosFiltrados.length,
                    itemBuilder: (context, index) =>
                        _buildProductoCard(productosFiltrados[index]),
                  ),
          ),
          Visibility(
            visible: hayCarrito,
            child: Container(
              width: double.infinity,
              height: 80,
              color: const Color(0xFF004B87),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Total Estimado',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${_totalEstimado.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResumenPedidoScreen(
                            cliente: widget.cliente,
                            carrito: _carrito,
                            horaInicio: _horaInicio,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF004B87),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Revisar Pedido (${_carrito.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriaChip(String nombre) {
    final isSelected = _categoriaSeleccionada == nombre;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _categoriaSeleccionada = nombre),
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
            nombre,
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

  Widget _buildProductoCard(Map<String, dynamic> producto) {
    final id = producto['id'] as int;
    final nombre = producto['nombre'] ?? '';
    final codigo = producto['codigo'] ?? '';
    final precio = double.tryParse(producto['precio_venta'].toString()) ?? 0;
    final cantidad = _getCantidad(id);
    final enCarrito = cantidad > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enCarrito
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textPrimary.withValues(alpha: 0.25),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (enCarrito)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'AGREGADO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'SKU: $codigo',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${precio.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (enCarrito)
            Row(
              children: [
                _buildBotonCantidad(Icons.remove, () => _quitarProducto(id)),
                GestureDetector(
                  onTap: () => _mostrarDialogoCantidad(producto, cantidad),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.cardBorder),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$cantidad',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                _buildBotonCantidad(
                  Icons.add,
                  () => _agregarProducto(producto),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: () => _agregarProducto(producto),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Agregar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBotonCantidad(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}
