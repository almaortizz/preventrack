import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'sesion_service.dart';

class ApiService {
  // 401 con un token enviado = la API ya no reconoce la sesión (p. ej. el
  // usuario fue bloqueado): se cierra y se manda al login
  void _revisarSesion(int statusCode, String? token) {
    if (statusCode == 401 && token != null) {
      unawaited(SesionService.sesionTerminada());
    }
  }

  // GET con token
  Future<Map<String, dynamic>> get(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/$endpoint'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    _revisarSesion(response.statusCode, token);
    return {
      'statusCode': response.statusCode,
      'data': jsonDecode(response.body),
    };
  }

  // GET de una lista paginada trayendo TODAS las páginas (de 100 en 100).
  // Regresa lo mismo que get(): {'statusCode', 'data'}, con 'data' = la
  // lista completa; si una página falla, regresa esa respuesta.
  Future<Map<String, dynamic>> obtenerTodos(String endpoint) async {
    final separador = endpoint.contains('?') ? '&' : '?';
    final todos = <dynamic>[];
    var pagina = 1;

    while (true) {
      final result = await get(
        '$endpoint${separador}per_page=100&page=$pagina',
      );
      if (result['statusCode'] != 200) return result;

      final data = result['data'];
      if (data is List) return result; // la API no pagina esa lista
      todos.addAll(data['data'] ?? []);

      final ultima = int.tryParse('${data['last_page'] ?? 1}') ?? 1;
      if (pagina >= ultima) return {'statusCode': 200, 'data': todos};
      pagina++;
    }
  }

  // POST con token
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: body != null ? jsonEncode(body) : null,
    );

    _revisarSesion(response.statusCode, token);
    return {
      'statusCode': response.statusCode,
      'data': jsonDecode(response.body),
    };
  }

  // PUT con token
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: body != null ? jsonEncode(body) : null,
    );

    _revisarSesion(response.statusCode, token);
    return {
      'statusCode': response.statusCode,
      'data': jsonDecode(response.body),
    };
  }

  // DELETE con token
  Future<Map<String, dynamic>> delete(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/$endpoint'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    _revisarSesion(response.statusCode, token);
    return {
      'statusCode': response.statusCode,
      'data': jsonDecode(response.body),
    };
  }
}
