import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth_service.dart';
import 'ubicacion_service.dart';

// Navegación global: permite mandar al login desde un servicio (p. ej. al
// recibir 401 en una petición), sin depender de una pantalla.
final GlobalKey<NavigatorState> navegadorGlobal = GlobalKey<NavigatorState>();

// Sesión que la API ya no reconoce (token borrado al bloquear al usuario,
// expirado, etc.): se cierra en el celular y se manda al login.
// NO borra la cola de operaciones pendientes, los pedidos rechazados ni lo
// guardado para trabajar sin conexión: se suben al volver a entrar.
class SesionService {
  static bool _cerrando = false;

  static Future<void> sesionTerminada() async {
    // Varias peticiones pueden recibir 401 a la vez: solo una vez
    if (_cerrando) return;
    _cerrando = true;

    try {
      // Sin sesión, el reporte de ubicación seguiría recibiendo 401
      UbicacionService.instancia.detener();

      final contexto = navegadorGlobal.currentContext;
      if (contexto != null && contexto.mounted) {
        await Provider.of<AuthProvider>(
          contexto,
          listen: false,
        ).sesionTerminada();
      } else {
        await AuthService().borrarSesionLocal();
      }

      navegadorGlobal.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (_) => false,
      );
    } finally {
      _cerrando = false;
    }
  }
}
