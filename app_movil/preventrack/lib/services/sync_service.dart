import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import 'database_service.dart';

class SyncService {
  static final ApiService _api = ApiService();

  /// Verificar si hay conexión intentando una petición simple
  static Future<bool> hayConexion() async {
    try {
      final result = await _api.get('me');
      return result['statusCode'] == 200;
    } catch (_) {
      return false;
    }
  }

  /// Descargar todos los datos necesarios para trabajar offline
  static Future<Map<String, dynamic>> sincronizarTodo() async {
    if (!DatabaseService.isAvailable) {
      return {'success': false, 'message': 'SQLite no disponible en web'};
    }

    int clientesSincronizados = 0;
    int productosSincronizados = 0;
    int categoriasSincronizadas = 0;
    bool rutaSincronizada = false;
    final errores = <String>[];

    // ── Descargar clientes ──
    try {
      final result = await _api.get('clientes');
      if (result['statusCode'] == 200) {
        final data = result['data'];
        final clientes = data is List ? data : (data['data'] ?? []);
        await DatabaseService.guardarClientes(clientes);
        clientesSincronizados = clientes.length;
      }
    } catch (e) {
      errores.add('Error al sincronizar clientes');
    }

    // ── Descargar productos ──
    try {
      final result = await _api.get('productos');
      if (result['statusCode'] == 200) {
        final data = result['data'];
        final productos = data is List ? data : (data['data'] ?? []);
        await DatabaseService.guardarProductos(productos);
        productosSincronizados = productos.length;
      }
    } catch (e) {
      errores.add('Error al sincronizar productos');
    }

    // ── Descargar categorías ──
    try {
      final result = await _api.get('categorias');
      if (result['statusCode'] == 200) {
        final data = result['data'];
        final categorias = data is List ? data : (data['data'] ?? []);
        await DatabaseService.guardarCategorias(categorias);
        categoriasSincronizadas = categorias.length;
      }
    } catch (e) {
      errores.add('Error al sincronizar categorías');
    }

    // ── Descargar ruta del día ──
    try {
      final result = await _api.get('ruta-del-dia');
      if (result['statusCode'] == 200) {
        final ruta = result['data']['ruta'];
        await DatabaseService.guardarRutaDelDia(ruta);
        rutaSincronizada = true;
      }
    } catch (e) {
      errores.add('Error al sincronizar ruta');
    }

    return {
      'success': errores.isEmpty,
      'clientes': clientesSincronizados,
      'productos': productosSincronizados,
      'categorias': categoriasSincronizadas,
      'ruta': rutaSincronizada,
      'errores': errores,
    };
  }

  static Future<Map<String, dynamic>>? _subidaEnCurso;

  /// Subir operaciones que se hicieron offline.
  /// Si ya hay una subida en curso (p. ej. desde el dashboard y el mapa a
  /// la vez) se reutiliza, para no enviar dos veces la misma operación.
  static Future<Map<String, dynamic>> subirPendientes() {
    return _subidaEnCurso ??= _subirPendientes().whenComplete(
      () => _subidaEnCurso = null,
    );
  }

  static Future<Map<String, dynamic>> _subirPendientes() async {
    if (!DatabaseService.isAvailable) {
      return {'success': false, 'subidas': 0, 'fallidas': 0};
    }

    final operaciones = await DatabaseService.obtenerOperacionesPendientes();
    int subidas = 0;
    int fallidas = 0;

    for (var op in operaciones) {
      try {
        final endpoint = op['endpoint'] as String;
        final metodo = op['metodo'] as String;
        final bodyStr = op['body'] as String?;
        final body = bodyStr != null
            ? jsonDecode(bodyStr) as Map<String, dynamic>
            : null;

        Map<String, dynamic> result;

        switch (metodo) {
          case 'POST':
            result = await _api.post(endpoint, body: body);
            break;
          case 'PUT':
            result = await _api.put(endpoint, body: body);
            break;
          case 'DELETE':
            result = await _api.delete(endpoint);
            break;
          default:
            result = {'statusCode': 400};
        }

        if (result['statusCode'] >= 200 && result['statusCode'] < 300) {
          await DatabaseService.eliminarOperacionPendiente(op['id'] as int);
          subidas++;
        } else if (op['tipo'] == 'visitar_parada' &&
            result['statusCode'] == 422) {
          // La parada ya quedó visitada (p. ej. por un pedido que se subió
          // antes); la visita en cola ya no aplica
          await DatabaseService.eliminarOperacionPendiente(op['id'] as int);
        } else if (_esOperacionEntrega(op['tipo']) &&
            (result['statusCode'] == 422 || result['statusCode'] == 404)) {
          // El pedido cambió en la oficina mientras no había conexión
          // (cancelado, reasignado, borrado): ya no se puede registrar y
          // reintentarlo no sirve. Se quita de la cola y se avisa.
          await DatabaseService.eliminarOperacionPendiente(op['id'] as int);
          final accion = op['tipo'] == 'entregar_pedido'
              ? 'la entrega'
              : 'el "no entregado"';
          final numero = body?['numero_orden'] ?? '';
          final motivo =
              (result['data'] is Map ? result['data']['message'] : null) ??
              'El pedido ya no está en ruta.';
          _rechazos.add(
            'No se pudo registrar $accion del pedido $numero. $motivo '
            'Avisa a la oficina.',
          );
        } else {
          fallidas++;
        }
      } catch (e) {
        fallidas++;
      }
    }

    return {
      'success': fallidas == 0,
      'subidas': subidas,
      'fallidas': fallidas,
    };
  }

  // ═══════════════════════════════════════════
  //  ENTREGAS SIN CONEXIÓN
  // ═══════════════════════════════════════════

  static bool _esOperacionEntrega(Object? tipo) =>
      tipo == 'entregar_pedido' || tipo == 'no_entregar_pedido';

  // Avisos de entregas que la API rechazó al sincronizar
  static final List<String> _rechazos = [];

  /// Devuelve los avisos pendientes de mostrar y los limpia
  static List<String> tomarRechazos() {
    final avisos = List<String>.from(_rechazos);
    _rechazos.clear();
    return avisos;
  }

  /// Aplica a la lista de entregas lo que se registró sin conexión y sigue
  /// en la cola: las entregadas quedan marcadas (pendientes de sincronizar)
  /// y las "no entregadas" se quitan, igual que cuando hay conexión.
  static Future<List<dynamic>> aplicarEntregasPendientes(
    List<dynamic> entregas,
  ) async {
    if (!DatabaseService.isAvailable) return entregas;

    final entregadas = <Object?>{};
    final noEntregadas = <Object?>{};
    for (final op in await DatabaseService.obtenerOperacionesPendientes()) {
      if (!_esOperacionEntrega(op['tipo'])) continue;
      final bodyStr = op['body'] as String?;
      if (bodyStr == null) continue;
      final ventaId = (jsonDecode(bodyStr) as Map<String, dynamic>)['venta_id'];
      if (op['tipo'] == 'entregar_pedido') {
        entregadas.add(ventaId);
      } else {
        noEntregadas.add(ventaId);
      }
    }

    return entregas.where((e) => !noEntregadas.contains(e['id'])).map((e) {
      if (!entregadas.contains(e['id'])) return e;
      return {
        ...(e as Map<String, dynamic>),
        'estado': 'entregado',
        'pendiente_sync': true,
      };
    }).toList();
  }
}
