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

  /// Subir operaciones que se hicieron offline
  static Future<Map<String, dynamic>> subirPendientes() async {
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
}
