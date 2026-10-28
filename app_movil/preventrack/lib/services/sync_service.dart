import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'database_service.dart';
import 'folio_service.dart';

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

        if (result['statusCode'] == 401) {
          // Sesión terminada: todas fallarían igual. Se queda en la cola y se
          // sube al volver a iniciar sesión.
          fallidas++;
          break;
        } else if (result['statusCode'] >= 200 && result['statusCode'] < 300) {
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
        } else if (op['tipo'] == 'crear_pedido' &&
            body != null &&
            _esConflictoDeFolio(result)) {
          // El folio ya pertenece a otro pedido (o no es válido): reintentarlo
          // no sirve. Se quita de la cola, se guarda una copia para
          // reenviarlo con folio nuevo y se avisa con los datos del pedido.
          await DatabaseService.eliminarOperacionPendiente(op['id'] as int);
          final motivo =
              (result['data'] is Map ? result['data']['message'] : null) ??
              'El folio ya está registrado en otro pedido.';
          await _guardarPedidoRechazado(body, motivo);
          _rechazos.add(
            'No se pudo registrar el pedido ${body['numero_orden']} '
            '(${describirPedido(body)}). $motivo Se guardó una copia: '
            'reenvíalo desde el Inicio con un folio nuevo.',
          );
        } else if (op['tipo'] == 'jornada' && result['statusCode'] == 422) {
          // La jornada cambió mientras no había conexión (p. ej. la oficina
          // la cerró): este registro ya no aplica. Se quita y se avisa.
          await DatabaseService.eliminarOperacionPendiente(op['id'] as int);
          const momentos = {
            'iniciar': 'el inicio de la jornada',
            'iniciar_comida': 'el inicio de la comida',
            'finalizar_comida': 'el fin de la comida',
            'finalizar': 'el fin de la jornada',
          };
          final motivo =
              (result['data'] is Map ? result['data']['message'] : null) ?? '';
          _rechazos.add(
            'No se pudo registrar ${momentos[body?['evento']] ?? 'la jornada'}. '
            '$motivo Avisa a la oficina.',
          );
        } else {
          fallidas++;
        }
      } catch (e) {
        fallidas++;
      }
    }

    // Lo subido pudo usar folios nuevos: actualizar el consecutivo
    if (subidas > 0) await FolioService.actualizarDesdeApi();

    return {'success': fallidas == 0, 'subidas': subidas, 'fallidas': fallidas};
  }

  // ═══════════════════════════════════════════
  //  PEDIDOS RECHAZADOS POR FOLIO
  // ═══════════════════════════════════════════

  static const _clavePedidosRechazados = 'pedidos_rechazados';

  // La API responde 422 con el error en "numero_orden"
  static bool _esConflictoDeFolio(Map<String, dynamic> result) {
    if (result['statusCode'] != 422) return false;
    final data = result['data'];
    final errores = data is Map ? data['errors'] : null;
    return errores is Map && errores.containsKey('numero_orden');
  }

  /// "Kevin · $596.00 · 19/10/2026 14:35" (datos que guarda la app en el pedido)
  static String describirPedido(Map<String, dynamic> body) {
    final cliente = body['cliente_nombre_local'] ?? 'Cliente';
    final total = double.tryParse(body['total_local']?.toString() ?? '') ?? 0;
    var fecha = '';
    try {
      final dt = DateTime.parse(body['fecha_fin_creacion'].toString());
      fecha =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}
    return [
      cliente,
      '\$${total.toStringAsFixed(2)}',
      if (fecha.isNotEmpty) fecha,
    ].join(' · ');
  }

  static Future<void> _guardarPedidoRechazado(
    Map<String, dynamic> body,
    String motivo,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = await obtenerPedidosRechazados();
    lista.add({'pedido': body, 'motivo': motivo});
    await prefs.setString(_clavePedidosRechazados, jsonEncode(lista));
  }

  /// Copias de pedidos rechazados por folio, guardadas en el celular
  static Future<List<Map<String, dynamic>>> obtenerPedidosRechazados() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_clavePedidosRechazados);
    if (guardado == null) return [];
    return (jsonDecode(guardado) as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> _quitarPedidoRechazado(int indice) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = await obtenerPedidosRechazados();
    if (indice < 0 || indice >= lista.length) return;
    lista.removeAt(indice);
    await prefs.setString(_clavePedidosRechazados, jsonEncode(lista));
  }

  /// Vuelve a poner en la cola el pedido rechazado con un folio nuevo y lo
  /// intenta subir. Regresa el folio nuevo (null si ya no existía).
  static Future<String?> reenviarPedidoRechazado(int indice) async {
    final lista = await obtenerPedidosRechazados();
    if (indice < 0 || indice >= lista.length) return null;

    final pedido = Map<String, dynamic>.from(lista[indice]['pedido'] as Map);
    final usuarioId = int.parse(pedido['preventista_vendedor_id'].toString());
    final folio = await FolioService.siguiente(usuarioId);
    pedido['numero_orden'] = folio;
    // El ticket impreso llevaba el folio anterior
    pedido.remove('impreso');

    await DatabaseService.guardarOperacionPendiente(
      tipo: 'crear_pedido',
      endpoint: 'ventas',
      metodo: 'POST',
      body: pedido,
    );
    await _quitarPedidoRechazado(indice);
    await subirPendientes();
    return folio;
  }

  /// Descarta la copia (p. ej. la oficina ya lo capturó a mano)
  static Future<void> descartarPedidoRechazado(int indice) =>
      _quitarPedidoRechazado(indice);

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
