import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    // Para celular Android, pon tu IP de red local
    return 'http://192.168.0.104/api';
  }
}
