import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  // GET con token
  Future<Map<String, dynamic>> get(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/$endpoint'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    return {
      'statusCode': response.statusCode,
      'data': jsonDecode(response.body),
    };
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

    return {
      'statusCode': response.statusCode,
      'data': jsonDecode(response.body),
    };
  }
}
