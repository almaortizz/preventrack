import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  // Ruta base de las imágenes de productos (storage público del backend).
  static String get storageUrl => 'http://127.0.0.1:8000/storage';
}
