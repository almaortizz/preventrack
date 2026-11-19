import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'database_service.dart';
import 'jornada_service.dart';

class AuthService {
  // Login: envía usuario y password, guarda el token
  Future<Map<String, dynamic>> login(String usuario, String password) async {
    final http.Response response;
    try {
      // Sin conexión la petición falla o se queda esperando: máximo 15 s
      response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'usuario': usuario, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return {
        'success': false,
        'message':
            'Sin conexión. Para iniciar sesión se necesita internet; '
            'revisa la conexión e intenta de nuevo.',
      };
    }

    // La API respondió, pero con algo que no se puede leer (error del servidor)
    final dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      return {'success': false, 'message': 'Error al iniciar sesión'};
    }

    if (response.statusCode == 200) {
      // Guardar token en almacenamiento local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('usuario', jsonEncode(data['usuario']));
      await _revisarCambioDeUsuario(prefs, data['usuario']);
      return {'success': true, 'data': data};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Error al iniciar sesión',
      };
    }
  }

  // Celular compartido: si entra alguien distinto al último usuario que
  // inició sesión aquí, se borra la ruta del día, las entregas y la jornada
  // guardadas del anterior. Como iniciar sesión requiere conexión, el nuevo
  // usuario las vuelve a descargar. La cola de cada quien se conserva.
  static const _claveUltimoUsuario = 'ultimo_usuario_id';

  Future<void> _revisarCambioDeUsuario(
    SharedPreferences prefs,
    dynamic usuario,
  ) async {
    final nuevo = int.tryParse('${usuario is Map ? usuario['id'] : ''}');
    if (nuevo == null) return;
    final anterior = prefs.getInt(_claveUltimoUsuario);
    if (anterior != nuevo) {
      await DatabaseService.limpiarDatosDelUsuarioAnterior();
      await JornadaService.borrarDatosLocales();
    }
    await prefs.setInt(_claveUltimoUsuario, nuevo);
  }

  // Logout: elimina el token del servidor y del almacenamiento local
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      // Se avisa a la API (máximo 5 s); sin conexión se cierra igual en el
      // celular, sin quedarse esperando
      try {
        await http
            .post(
              Uri.parse('${ApiConfig.baseUrl}/logout'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    await borrarSesionLocal();
  }

  // Borra solo la sesión del celular (token y usuario). No toca la cola de
  // operaciones pendientes ni los datos guardados para trabajar sin conexión.
  Future<void> borrarSesionLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('usuario');
  }

  // Verificar si hay sesión guardada
  Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  // Obtener el token guardado
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Obtener datos del usuario guardado
  Future<Map<String, dynamic>?> getUsuarioGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioStr = prefs.getString('usuario');
    if (usuarioStr != null) {
      return jsonDecode(usuarioStr);
    }
    return null;
  }

  // Actualizar datos del usuario guardado localmente
  Future<void> actualizarUsuarioLocal(Map<String, dynamic> cambios) async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioStr = prefs.getString('usuario');
    if (usuarioStr != null) {
      final usuario = jsonDecode(usuarioStr) as Map<String, dynamic>;
      usuario.addAll(cambios);
      await prefs.setString('usuario', jsonEncode(usuario));
    }
  }
}
