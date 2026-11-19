import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
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
      version: 5,
      onCreate: _crearTablas,
      onUpgrade: (db, oldVersion, newVersion) async {
        // v2: se guarda la imagen del producto para el modo sin conexión.
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE productos ADD COLUMN imagen TEXT');
        }
        // v3: lista de entregas para el modo sin conexión.
        if (oldVersion < 3) {
          await _crearTablaEntregas(db);
        }
        // v4: última consulta de Pedidos e Inicio para el modo sin conexión.
        if (oldVersion < 4) {
          await _crearTablaCopias(db);
        }
        // v5: de quién es cada operación pendiente (celular compartido).
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE operaciones_pendientes ADD COLUMN usuario_id INTEGER',
          );
        }
      },
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
        estado TEXT DEFAULT 'activo',
        imagen TEXT
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
        fecha_creacion TEXT,
        usuario_id INTEGER
      )
    ''');

    await _crearTablaEntregas(db);
    await _crearTablaCopias(db);
  }

  static Future<void> _crearTablaEntregas(Database db) async {
    await db.execute('''
      CREATE TABLE entregas (
        id INTEGER PRIMARY KEY,
        datos TEXT
      )
    ''');
  }

  // Copia de la última consulta de una pantalla (p. ej. 'pedidos' o
  // 'dashboard'), con el usuario al que pertenece y la hora en que se guardó
  static Future<void> _crearTablaCopias(Database db) async {
    await db.execute('''
      CREATE TABLE copias_consulta (
        clave TEXT PRIMARY KEY,
        usuario_id INTEGER,
        datos TEXT,
        fecha TEXT
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
          'imagen': producto['imagen'],
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
  //  ENTREGAS (pedidos en ruta del repartidor)
  // ═══════════════════════════════════════════

  static Future<void> guardarEntregas(List<dynamic> entregas) async {
    if (!isAvailable) return;
    final db = await database;

    await db.delete('entregas');
    await db.insert('entregas', {'id': 1, 'datos': jsonEncode(entregas)});
  }

  static Future<List<dynamic>> obtenerEntregas() async {
    if (!isAvailable) return [];
    final db = await database;
    final rows = await db.query('entregas', limit: 1);

    if (rows.isEmpty) return [];
    return jsonDecode(rows.first['datos'] as String) as List<dynamic>;
  }

  // ═══════════════════════════════════════════
  //  COPIAS DE CONSULTAS (Pedidos, Inicio)
  // ═══════════════════════════════════════════

  /// Guarda la última respuesta de una pantalla para verla sin conexión.
  static Future<void> guardarCopia(
    String clave,
    int? usuarioId,
    dynamic datos,
  ) async {
    if (!isAvailable || usuarioId == null) return;
    final db = await database;
    await db.insert('copias_consulta', {
      'clave': clave,
      'usuario_id': usuarioId,
      'datos': jsonEncode(datos),
      'fecha': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Regresa {'datos', 'fecha'} de la última copia, solo si es del mismo
  /// usuario (en un celular compartido no se ven los datos de otro).
  static Future<Map<String, dynamic>?> obtenerCopia(
    String clave,
    int? usuarioId,
  ) async {
    if (!isAvailable || usuarioId == null) return null;
    final db = await database;
    final rows = await db.query(
      'copias_consulta',
      where: 'clave = ? AND usuario_id = ?',
      whereArgs: [clave, usuarioId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return {
      'datos': jsonDecode(rows.first['datos'] as String),
      'fecha': DateTime.tryParse(rows.first['fecha'] as String? ?? ''),
    };
  }

  // ═══════════════════════════════════════════
  //  OPERACIONES PENDIENTES (SYNC)
  // ═══════════════════════════════════════════

  /// Pedidos levantados sin conexión que siguen en la cola (sin subir)
  static Future<List<Map<String, dynamic>>> obtenerPedidosEnCola() async {
    if (!isAvailable) return [];
    final db = await database;
    final (where, args) = await _filtroDelUsuario();
    final operaciones = await db.query(
      'operaciones_pendientes',
      where: 'tipo = ? AND $where',
      whereArgs: ['crear_pedido', ...args],
      orderBy: 'id DESC',
    );
    final pedidos = <Map<String, dynamic>>[];
    for (final op in operaciones) {
      final bodyStr = op['body'] as String?;
      if (bodyStr == null) continue;
      pedidos.add(jsonDecode(bodyStr) as Map<String, dynamic>);
    }
    return pedidos;
  }

  /// Id del usuario con sesión en el celular (null si no hay sesión)
  static Future<int?> usuarioActualId() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioStr = prefs.getString('usuario');
    if (usuarioStr == null) return null;
    try {
      final usuario = jsonDecode(usuarioStr) as Map<String, dynamic>;
      return int.tryParse('${usuario['id']}');
    } catch (_) {
      return null;
    }
  }

  // Celular compartido: cada operación es de quien la hizo y solo se ve y se
  // sube con su sesión. Las de antes de la v5 (sin dueño) se tratan como del
  // usuario con sesión, como antes.
  static Future<(String, List<Object?>)> _filtroDelUsuario() async {
    final usuarioId = await usuarioActualId();
    if (usuarioId == null) return ('usuario_id IS NULL', <Object?>[]);
    return ('(usuario_id IS NULL OR usuario_id = ?)', <Object?>[usuarioId]);
  }

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
      'usuario_id': await usuarioActualId(),
    });
  }

  /// Operaciones pendientes del usuario con sesión
  static Future<List<Map<String, dynamic>>>
  obtenerOperacionesPendientes() async {
    if (!isAvailable) return [];
    final db = await database;
    final (where, args) = await _filtroDelUsuario();
    return await db.query(
      'operaciones_pendientes',
      where: where,
      whereArgs: args,
      orderBy: 'id ASC',
    );
  }

  static Future<void> eliminarOperacionPendiente(int id) async {
    if (!isAvailable) return;
    final db = await database;
    await db.delete('operaciones_pendientes', where: 'id = ?', whereArgs: [id]);
  }

  /// Marca como impreso el pedido de la cola con ese folio (ticket impreso
  /// sin conexión). Regresa false si ya no está en la cola.
  static Future<bool> marcarPedidoEnColaComoImpreso(String folio) async {
    if (!isAvailable) return false;
    final db = await database;
    final operaciones = await db.query(
      'operaciones_pendientes',
      where: 'tipo = ?',
      whereArgs: ['crear_pedido'],
    );

    for (final op in operaciones) {
      final bodyStr = op['body'] as String?;
      if (bodyStr == null) continue;
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      if (body['numero_orden'] != folio) continue;

      body['impreso'] = true;
      await db.update(
        'operaciones_pendientes',
        {'body': jsonEncode(body)},
        where: 'id = ?',
        whereArgs: [op['id']],
      );
      return true;
    }
    return false;
  }

  /// Cuántas operaciones pendientes tiene el usuario con sesión
  static Future<int> contarOperacionesPendientes() async {
    if (!isAvailable) return 0;
    final db = await database;
    final (where, args) = await _filtroDelUsuario();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM operaciones_pendientes WHERE $where',
      args,
    );
    return result.first['count'] as int;
  }

  /// Al entrar un usuario distinto al anterior en este celular: se borran
  /// los datos que son de una persona (su ruta del día y sus entregas).
  /// Clientes, productos y categorías son de todos y se conservan; la cola
  /// no se toca (cada operación ya sabe de quién es).
  static Future<void> limpiarDatosDelUsuarioAnterior() async {
    if (!isAvailable) return;
    final db = await database;
    await db.delete('ruta_del_dia');
    await db.delete('entregas');
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
    await db.delete('entregas');
    await db.delete('copias_consulta');
    await db.delete('operaciones_pendientes');
  }
}
