import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';

class PrintService {
  static String? _macConectada;

  // Papel de 58 mm = 32 caracteres por línea (fuente normal)
  static const PaperSize _papel = PaperSize.mm58;
  static const int _anchoLinea = 32;
  static const int _anchoLogoPx = 200; // máximo 384 px en 58 mm

  // ═══════════════════════════════════════════
  //  PERMISOS
  // ═══════════════════════════════════════════

  /// Pide el permiso "Dispositivos cercanos" (Android 12+).
  /// En Android 11 o menor el sistema lo da por concedido.
  static Future<bool> _asegurarPermisos(BuildContext context) async {
    final estado = await Permission.bluetoothConnect.request();
    if (estado.isGranted) return true;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Se necesita el permiso de Dispositivos cercanos para imprimir',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: estado.isPermanentlyDenied
              ? SnackBarAction(
                  label: 'Ajustes',
                  textColor: Colors.white,
                  onPressed: openAppSettings,
                )
              : null,
        ),
      );
    }
    return false;
  }

  // ═══════════════════════════════════════════
  //  CONEXIÓN BLUETOOTH
  // ═══════════════════════════════════════════

  static Future<List<BluetoothInfo>> obtenerDispositivos() async {
    try {
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      return [];
    }
  }

  static Future<bool> conectar(BluetoothInfo device) async {
    try {
      final ok = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.macAdress,
      );
      if (ok) _macConectada = device.macAdress;
      return ok;
    } catch (e) {
      return false;
    }
  }

  static Future<void> desconectar() async {
    try {
      await PrintBluetoothThermal.disconnect;
      _macConectada = null;
    } catch (_) {}
  }

  static Future<bool> estaConectado() async {
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  /// MAC de la impresora conectada en esta sesión (null si ninguna).
  static String? get macConectada => _macConectada;

  // ═══════════════════════════════════════════
  //  UTILIDADES DE FORMATO
  // ═══════════════════════════════════════════

  /// Quita acentos y caracteres que la impresora no puede imprimir.
  static String _limpiar(String texto) {
    const conAcento = 'áéíóúÁÉÍÓÚñÑüÜ';
    const sinAcento = 'aeiouAEIOUnNuU';
    final buffer = StringBuffer();
    for (final ch in texto.split('')) {
      final i = conAcento.indexOf(ch);
      if (i >= 0) {
        buffer.write(sinAcento[i]);
      } else if (ch.codeUnitAt(0) >= 32 && ch.codeUnitAt(0) < 127) {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// Texto a la izquierda y a la derecha en la misma línea.
  static String _izqDer(String izq, String der, {int ancho = _anchoLinea}) {
    izq = _limpiar(izq);
    der = _limpiar(der);
    final espacio = ancho - der.length - 1;
    if (izq.length > espacio) izq = izq.substring(0, espacio);
    return izq.padRight(ancho - der.length) + der;
  }

  /// Parte un texto en líneas de máximo [ancho] caracteres sin cortar palabras.
  static List<String> _partirTexto(String texto, int ancho) {
    final palabras = _limpiar(texto).split(' ').where((p) => p.isNotEmpty);
    final lineas = <String>[];
    var actual = '';
    for (var palabra in palabras) {
      // Palabra más larga que la línea: se corta a la fuerza
      while (palabra.length > ancho) {
        if (actual.isNotEmpty) {
          lineas.add(actual);
          actual = '';
        }
        lineas.add(palabra.substring(0, ancho));
        palabra = palabra.substring(ancho);
      }
      if (actual.isEmpty) {
        actual = palabra;
      } else if (actual.length + 1 + palabra.length <= ancho) {
        actual = '$actual $palabra';
      } else {
        lineas.add(actual);
        actual = palabra;
      }
    }
    if (actual.isNotEmpty) lineas.add(actual);
    return lineas.isEmpty ? [''] : lineas;
  }

  static String _dinero(double valor) => '\$${valor.toStringAsFixed(2)}';

  /// Carga el logo, lo pone sobre fondo blanco y lo ajusta al ancho del papel.
  static Future<img.Image?> _cargarLogo() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      final original = img.decodeImage(data.buffer.asUint8List());
      if (original == null) return null;

      final ajustado = original.width > _anchoLogoPx
          ? img.copyResize(original, width: _anchoLogoPx)
          : original;

      // Las zonas transparentes del PNG se imprimirían en negro:
      // se pinta primero un fondo blanco
      final fondo = img.Image(width: ajustado.width, height: ajustado.height);
      img.fill(fondo, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(fondo, ajustado);
      return fondo;
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════
  //  ARMAR TICKET (bytes ESC/POS)
  // ═══════════════════════════════════════════

  static Future<List<int>> _armarTicket({
    required Map<String, dynamic> venta,
    required String preventistaNombre,
  }) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(_papel, profile);
    List<int> bytes = [];

    const centro = PosStyles(align: PosAlign.center);
    const centroNegrita = PosStyles(align: PosAlign.center, bold: true);
    const negrita = PosStyles(bold: true);
    final separador = '-' * _anchoLinea;

    // ── Datos de la venta ──
    final numeroOrden = (venta['numero_orden'] ?? '').toString();
    final totalNum = double.tryParse(venta['total']?.toString() ?? '0') ?? 0;
    final descuentoNum =
        double.tryParse(venta['descuento']?.toString() ?? '0') ?? 0;
    final createdAt = (venta['created_at'] ?? '').toString();

    String clienteNombre = 'Cliente';
    final domicilio = venta['domicilio'];
    if (domicilio != null && domicilio['cliente'] != null) {
      clienteNombre =
          (domicilio['cliente']['nombre_negocio'] ?? 'Cliente').toString();
    }

    final detalle = venta['detalle'] as List<dynamic>? ?? [];

    double subtotal = 0;
    int totalUnidades = 0;
    for (var item in detalle) {
      final cantidad = num.tryParse(item['cantidad']?.toString() ?? '0') ?? 0;
      final precio =
          double.tryParse(item['precio_unitario']?.toString() ?? '0') ?? 0;
      subtotal += cantidad * precio;
      totalUnidades += cantidad.toInt();
    }

    // ── Fecha y hora (Laravel envía UTC → se convierte a hora local) ──
    String fecha = '';
    String hora = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        fecha =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
        final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final amPm = dt.hour >= 12 ? 'PM' : 'AM';
        hora =
            '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')} $amPm';
      } catch (_) {}
    }

    // ── IMPRIMIR ──
    bytes += g.reset();

    // Logo
    final logo = await _cargarLogo();
    if (logo != null) {
      bytes += g.image(logo, align: PosAlign.center);
      bytes += g.feed(1);
    }

    // Encabezado
    bytes += g.text(
      'DISTRIBUIDORA BELLA LUZ',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
      ),
    );
    bytes += g.text('R.F.C. HEAA760906DJ4', styles: centro);
    bytes += g.text('Calle 95 Ote. #1015-2', styles: centro);
    bytes += g.text('Col. Granjas Ejidales San Isidro', styles: centro);
    bytes += g.text('Puebla, Pue. C.P. 72587', styles: centro);
    bytes += g.text(separador);

    // Info del pedido
    bytes += g.text(_izqDer('# Remision:', numeroOrden));
    bytes += g.text(_izqDer('Fecha:', fecha));
    bytes += g.text(_izqDer('Hora:', hora));
    bytes += g.text(_izqDer('Preventista:', preventistaNombre));
    bytes += g.text(separador);

    // Cliente (nombre largo se parte en varias líneas)
    bytes += g.text('CLIENTE', styles: negrita);
    for (final linea in _partirTexto(clienteNombre, _anchoLinea)) {
      bytes += g.text(linea, styles: negrita);
    }
    bytes += g.text(separador);

    // Productos
    bytes += g.text('PRODUCTOS', styles: negrita);
    bytes += g.text(_izqDer('Cant  Codigo/Producto', 'Importe'));
    bytes += g.text(separador);

    for (var item in detalle) {
      final producto = item['producto'];
      final nombre = (producto?['nombre'] ?? 'Producto').toString();
      final codigo = (producto?['codigo'] ?? '').toString();
      final cantidad = num.tryParse(item['cantidad']?.toString() ?? '0') ?? 0;
      final precio =
          double.tryParse(item['precio_unitario']?.toString() ?? '0') ?? 0;
      final importe = _dinero((cantidad * precio).toDouble());

      // Línea del código
      if (codigo.isNotEmpty) {
        bytes += g.text('      ${_limpiar(codigo)}');
      }

      // Cantidad + nombre (partido en líneas) + importe a la derecha
      final prefijo = '$cantidad'.padRight(3);
      final anchoNombre = _anchoLinea - prefijo.length - importe.length - 1;
      final lineasNombre = _partirTexto(nombre, anchoNombre);

      bytes += g.text(_izqDer('$prefijo${lineasNombre.first}', importe));
      for (final extra in lineasNombre.skip(1)) {
        bytes += g.text('${' ' * prefijo.length}$extra');
      }

      // Precio unitario
      bytes += g.text('   x ${_dinero(precio)}');
    }

    bytes += g.text(separador);

    // Totales
    bytes += g.text(_izqDer('Subtotal:', _dinero(subtotal)));
    bytes += g.text(_izqDer('Descuento:', _dinero(descuentoNum)));
    bytes += g.text(_izqDer('IVA:', _dinero(0)));
    bytes += g.feed(1);

    // TOTAL en letra doble (16 caracteres por línea); si no cabe, normal
    final totalTexto = _dinero(totalNum);
    if ('TOTAL: $totalTexto'.length <= _anchoLinea ~/ 2) {
      bytes += g.text(
        _izqDer('TOTAL:', totalTexto, ancho: _anchoLinea ~/ 2),
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
    } else {
      bytes += g.text(_izqDer('TOTAL:', totalTexto), styles: negrita);
    }

    bytes += g.text(separador);
    bytes += g.text(_izqDer('Articulos:', '$totalUnidades unidades'));
    bytes += g.text(separador);

    // Pie
    bytes += g.text('Gracias por su compra!', styles: centroNegrita);
    bytes += g.text('Cel. 22 24 63 35 56', styles: centro);
    bytes += g.text('angelo13467@gmail.com', styles: centro);
    bytes += g.feed(1);
    bytes += g.text('Preventrack', styles: centro);
    bytes += g.feed(3);

    return bytes;
  }

  // ═══════════════════════════════════════════
  //  IMPRIMIR TICKET
  // ═══════════════════════════════════════════

  static Future<bool> imprimirTicket({
    required Map<String, dynamic> venta,
    required String preventistaNombre,
  }) async {
    try {
      final conectado = await estaConectado();
      if (!conectado) return false;

      final bytes = await _armarTicket(
        venta: venta,
        preventistaNombre: preventistaNombre,
      );
      final ok = await PrintBluetoothThermal.writeBytes(bytes);

      if (ok) await _marcarImpreso(venta);
      return ok;
    } catch (e) {
      return false;
    }
  }

  /// Avisa a la API que el ticket ya se imprimió (bloquea la edición).
  /// Si falla, no afecta la impresión.
  static Future<void> _marcarImpreso(Map<String, dynamic> venta) async {
    final id = venta['id'];
    if (id == null) return; // pedidos offline aún sin ID
    try {
      await ApiService().post('ventas/$id/marcar-impreso');
    } catch (_) {}
  }

  // ═══════════════════════════════════════════
  //  DIÁLOGO SELECTOR DE IMPRESORA
  // ═══════════════════════════════════════════

  static Future<bool> mostrarDialogoImpresora(
    BuildContext context, {
    required Map<String, dynamic> venta,
    required String preventistaNombre,
  }) async {
    // Permiso de Bluetooth (Android 12+)
    final permisoOk = await _asegurarPermisos(context);
    if (!permisoOk) return false;

    // Bluetooth encendido
    final bluetoothOn = await PrintBluetoothThermal.bluetoothEnabled;
    if (!bluetoothOn) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enciende el Bluetooth para imprimir'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    // Verificar si ya está conectada
    final conectado = await estaConectado();
    if (conectado) {
      // Ya conectada, imprimir directo
      final resultado = await imprimirTicket(
        venta: venta,
        preventistaNombre: preventistaNombre,
      );
      return resultado;
    }

    // Buscar dispositivos
    final dispositivos = await obtenerDispositivos();

    if (!context.mounted) return false;

    // Mostrar selector
    final seleccionado = await showModalBottomSheet<BluetoothInfo>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Seleccionar impresora',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Dispositivos Bluetooth vinculados',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            if (dispositivos.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth_disabled,
                      size: 40,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No se encontraron dispositivos',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vincula tu impresora en Ajustes de Bluetooth',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              )
            else
              ...dispositivos.map(
                (device) => ListTile(
                  leading: const Icon(Icons.print, color: Colors.blue),
                  title: Text(
                    device.name.isNotEmpty ? device.name : 'Dispositivo',
                  ),
                  subtitle: Text(
                    device.macAdress,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.pop(ctx, device),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (seleccionado == null) return false;

    // Conectar e imprimir
    if (!context.mounted) return false;

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Conectando e imprimiendo...'),
              ],
            ),
          ),
        ),
      ),
    );

    final conectadoOk = await conectar(seleccionado);

    if (!conectadoOk) {
      if (context.mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo conectar a la impresora'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    // Esperar un momento para que se estabilice la conexión
    await Future.delayed(const Duration(milliseconds: 500));

    final resultado = await imprimirTicket(
      venta: venta,
      preventistaNombre: preventistaNombre,
    );

    if (context.mounted) {
      Navigator.pop(context); // Cerrar loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado ? 'Ticket impreso correctamente' : 'Error al imprimir',
          ),
          backgroundColor: resultado ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return resultado;
  }
}
