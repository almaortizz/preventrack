import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _db;

  // SQLite no funciona en web
  static bool get isAvailable => !kIsWeb;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'preventrack_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _crearTablas,
    );
  }

  static Future<void> _crearTablas(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY,
        folio TEXT,
        nombre_negocio TEXT,
        propietario TEXT,
        telefono TEXT,
        zona TEXT,
        estado TEXT DEFAULT 'activo',
        domicilios TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY,
        codigo TEXT,
        nombre TEXT,
        descripcion TEXT,
        precio_venta REAL,
        categoria_id INTEGER,
        categoria_nombre TEXT,
        estado TEXT DEFAULT 'activo'
      )
    ''');

    await db.execute('''
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY,
        nombre TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ruta_del_dia (
        id INTEGER PRIMARY KEY,
        datos TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE operaciones_pendientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT,
        endpoint TEXT,
        metodo TEXT,
        body TEXT,
        fecha_creacion TEXT
      )
    ''');
  }

  // ═══════════════════════════════════════════
  //  CLIENTES
  // ═══════════════════════════════════════════

  static Future<void> guardarClientes(List<dynamic> clientes) async {
    if (!isAvailable) return;
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('clientes');
      for (var cliente in clientes) {
        await txn.insert('clientes', {
          'id': cliente['id'],
          'folio': cliente['folio'],
          'nombre_negocio': cliente['nombre_negocio'],
          'propietario': cliente['propietario'],
          'telefono': cliente['telefono'],
          'zona': cliente['zona'],
          'estado': cliente['estado'],
          'domicilios': cliente['domicilios'] != null
              ? jsonEncode(cliente['domicilios'])
              : null,
        });
      }
    });
  }

  static Future<List<Map<String, dynamic>>> obtenerClientes() async {
    if (!isAvailable) return [];
    final db = await database;
    final rows = await db.query('clientes');

    return rows.map((row) {
      final mapa = Map<String, dynamic>.from(row);
      if (mapa['domicilios'] != null) {
        mapa['domicilios'] = jsonDecode(mapa['domicilios'] as String);
      } else {
        mapa['domicilios'] = [];
      }
      return mapa;
    }).toList();
  }

  // ═══════════════════════════════════════════
  //  PRODUCTOS
  // ═══════════════════════════════════════════

  static Future<void> guardarProductos(List<dynamic> productos) async {
    if (!isAvailable) return;
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('productos');
      for (var producto in productos) {
        final categoria = producto['categoria'];
        await txn.insert('productos', {
          'id': producto['id'],
          'codigo': producto['codigo'],
          'nombre': producto['nombre'],
          'descripcion': producto['descripcion'],
          'precio_venta': producto['precio_venta'] is String
              ? double.tryParse(producto['precio_venta']) ?? 0
              : producto['precio_venta'],
          'categoria_id': producto['categoria_id'],
          'categoria_nombre': categoria != null ? categoria['nombre'] : null,
          'estado': producto['estado'],
        });
      }
    });
  }

  static Future<List<Map<String, dynamic>>> obtenerProductos() async {
    if (!isAvailable) return [];
    final db = await database;
    final rows = await db.query('productos');

    return rows.map((row) {
      final mapa = Map<String, dynamic>.from(row);
      if (mapa['categoria_nombre'] != null) {
        mapa['categoria'] = {
          'id': mapa['categoria_id'],
          'nombre': mapa['categoria_nombre'],
        };
      }
      return mapa;
    }).toList();
  }

  // ═══════════════════════════════════════════
  //  CATEGORÍAS
  // ═══════════════════════════════════════════

  static Future<void> guardarCategorias(List<dynamic> categorias) async {
    if (!isAvailable) return;
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('categorias');
      for (var cat in categorias) {
        await txn.insert('categorias', {
          'id': cat['id'],
          'nombre': cat['nombre'],
        });
      }
    });
  }

  static Future<List<Map<String, dynamic>>> obtenerCategorias() async {
    if (!isAvailable) return [];
    final db = await database;
    return await db.query('categorias');
  }

  // ═══════════════════════════════════════════
  //  RUTA DEL DÍA
  // ═══════════════════════════════════════════

  static Future<void> guardarRutaDelDia(Map<String, dynamic>? ruta) async {
    if (!isAvailable) return;
    final db = await database;

    await db.delete('ruta_del_dia');
    if (ruta != null) {
      await db.insert('ruta_del_dia', {
        'id': ruta['id'] ?? 1,
        'datos': jsonEncode(ruta),
      });
    }
  }

  static Future<Map<String, dynamic>?> obtenerRutaDelDia() async {
    if (!isAvailable) return null;
    final db = await database;
    final rows = await db.query('ruta_del_dia', limit: 1);

    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['datos'] as String);
  }

  // ═══════════════════════════════════════════
  //  OPERACIONES PENDIENTES (SYNC)
  // ═══════════════════════════════════════════

  static Future<void> guardarOperacionPendiente({
    required String tipo,
    required String endpoint,
    required String metodo,
    Map<String, dynamic>? body,
  }) async {
    if (!isAvailable) return;
    final db = await database;

    await db.insert('operaciones_pendientes', {
      'tipo': tipo,
      'endpoint': endpoint,
      'metodo': metodo,
      'body': body != null ? jsonEncode(body) : null,
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> obtenerOperacionesPendientes() async {
    if (!isAvailable) return [];
    final db = await database;
    return await db.query('operaciones_pendientes', orderBy: 'id ASC');
  }

  static Future<void> eliminarOperacionPendiente(int id) async {
    if (!isAvailable) return;
    final db = await database;
    await db.delete('operaciones_pendientes', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> contarOperacionesPendientes() async {
    if (!isAvailable) return 0;
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM operaciones_pendientes',
    );
    return result.first['count'] as int;
  }

  // ═══════════════════════════════════════════
  //  UTILIDADES
  // ═══════════════════════════════════════════

  static Future<void> limpiarTodo() async {
    if (!isAvailable) return;
    final db = await database;
    await db.delete('clientes');
    await db.delete('productos');
    await db.delete('categorias');
    await db.delete('ruta_del_dia');
    await db.delete('operaciones_pendientes');
  }
}
