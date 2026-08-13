import 'package:flutter/material.dart';
import 'dart:async';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class JornadaScreen extends StatefulWidget {
  const JornadaScreen({super.key});

  @override
  State<JornadaScreen> createState() => _JornadaScreenState();
}

class _JornadaScreenState extends State<JornadaScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _jornada;
  bool _isLoading = true;
  bool _isProcessing = false;
  Timer? _timer;
  Duration _tiempoAcumulado = Duration.zero;

  @override
  void initState() {
    super.initState();
    _cargarJornada();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarJornada() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.get('jornadas');
      if (result['statusCode'] == 200) {
        final data = result['data'];
        final jornadas = data is List ? data : (data['data'] ?? []);

        // Buscar jornada activa (sin hora_fin)
        Map<String, dynamic>? activa;
        for (var j in jornadas) {
          if (j['hora_fin'] == null) {
            activa = j;
            break;
          }
        }
        setState(() {
          _jornada = activa;
          _isLoading = false;
        });
        _iniciarTimer();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _iniciarTimer() {
    _timer?.cancel();
    if (_jornada != null &&
        _jornada!['hora_inicio'] != null &&
        _jornada!['hora_fin'] == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_jornada != null && _jornada!['hora_inicio'] != null) {
          final inicio = DateTime.parse(_jornada!['hora_inicio']);
          setState(() {
            _tiempoAcumulado = DateTime.now().toUtc().difference(inicio);
          });
        }
      });
    }
  }

  String get _tiempoFormateado {
    final horas = _tiempoAcumulado.inHours.toString().padLeft(2, '0');
    final minutos = (_tiempoAcumulado.inMinutes % 60).toString().padLeft(
      2,
      '0',
    );
    final segundos = (_tiempoAcumulado.inSeconds % 60).toString().padLeft(
      2,
      '0',
    );
    return '$horas:$minutos:$segundos';
  }

  String get _estadoJornada {
    if (_jornada == null) return 'no_iniciada';
    if (_jornada!['hora_fin'] != null) return 'finalizada';
    if (_jornada!['hora_inicio_comida'] != null &&
        _jornada!['hora_fin_comida'] == null)
      return 'en_comida';
    return 'en_curso';
  }

  Future<void> _iniciarJornada() async {
    setState(() => _isProcessing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final usuarioStr = prefs.getString('usuario');
      int? usuarioId;
      if (usuarioStr != null) {
        final userData = jsonDecode(usuarioStr);
        usuarioId = userData['id'];
      }
      final result = await _api.post(
        'jornadas/iniciar',
        body: {'usuario_id': usuarioId},
      );
      if (result['statusCode'] == 201 || result['statusCode'] == 200) {
        await _cargarJornada();
      } else {
        if (mounted) {
          final msg = result['data']['message'] ?? 'Error al iniciar jornada';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error de conexion')));
      }
    }
    setState(() => _isProcessing = false);
  }

  Future<void> _iniciarComida() async {
    setState(() => _isProcessing = true);
    try {
      final result = await _api.post(
        'jornadas/${_jornada!['id']}/iniciar-comida',
      );
      if (result['statusCode'] == 200) {
        await _cargarJornada();
      } else {
        if (mounted) {
          final msg = result['data']['message'] ?? 'Error al iniciar comida';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error de conexion')));
      }
    }
    setState(() => _isProcessing = false);
  }

  Future<void> _finalizarComida() async {
    setState(() => _isProcessing = true);
    try {
      final result = await _api.post(
        'jornadas/${_jornada!['id']}/finalizar-comida',
      );
      if (result['statusCode'] == 200) {
        await _cargarJornada();
      } else {
        if (mounted) {
          final msg = result['data']['message'] ?? 'Error al finalizar comida';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error de conexion')));
      }
    }
    setState(() => _isProcessing = false);
  }

  Future<void> _finalizarJornada() async {
    setState(() => _isProcessing = true);
    try {
      final result = await _api.post('jornadas/${_jornada!['id']}/finalizar');
      if (result['statusCode'] == 200) {
        _timer?.cancel();
        await _cargarJornada();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jornada finalizada'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final msg = result['data']['message'] ?? 'Error al finalizar jornada';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error de conexion')));
      }
    }
    setState(() => _isProcessing = false);
  }

  void _confirmarAccion(
    String titulo,
    String mensaje,
    VoidCallback onConfirmar,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          titulo,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirmar();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  String _formatHora(String? fecha) {
    if (fecha == null) return '--:--';
    try {
      final dt = DateTime.parse(fecha);
      final hora = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final hora12 = dt.hour > 12
          ? (dt.hour - 12)
          : (dt.hour == 0 ? 12 : dt.hour);
      return '${hora12.toString().padLeft(2, '0')}:$min $amPm';
    } catch (_) {
      return '--:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = _estadoJornada;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Jornada Laboral',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        surfaceTintColor: AppColors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.cardBorder.withValues(alpha: 0.5),
            height: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Estado actual
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: estado == 'en_curso'
                                ? AppColors.success
                                : estado == 'en_comida'
                                ? AppColors.warning
                                : estado == 'no_iniciada'
                                ? Colors.grey
                                : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          estado == 'en_curso'
                              ? 'Estado: En curso'
                              : estado == 'en_comida'
                              ? 'Estado: En comida'
                              : estado == 'no_iniciada'
                              ? 'Estado: No iniciada'
                              : 'Estado: Finalizada',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: estado == 'en_curso'
                                ? AppColors.success
                                : estado == 'en_comida'
                                ? AppColors.warning
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cronometro
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TIEMPO TOTAL ACUMULADO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.45,
                            ),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          estado == 'no_iniciada'
                              ? '00:00:00'
                              : _tiempoFormateado,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botones de accion
                  if (estado == 'no_iniciada')
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _iniciarJornada,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(Icons.play_arrow, size: 22),
                        label: Text(_isProcessing ? '' : 'Iniciar Jornada'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  if (estado == 'en_curso') ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _iniciarComida,
                        icon: const Icon(Icons.restaurant, size: 20),
                        label: const Text('Iniciar Comida'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : () => _confirmarAccion(
                                'Finalizar Jornada',
                                'Estas seguro de finalizar tu jornada laboral?',
                                _finalizarJornada,
                              ),
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Finalizar Jornada'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (estado == 'en_comida')
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _finalizarComida,
                        icon: const Icon(Icons.restaurant, size: 20),
                        label: const Text('Finalizar Comida'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Resumen de registros
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Resumen de Registros',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildRegistroItem(
                    Icons.login,
                    AppColors.primary,
                    'Inicio de Jornada',
                    _jornada != null
                        ? _formatHora(_jornada!['hora_inicio'])
                        : '--:--',
                    activo:
                        _jornada != null && _jornada!['hora_inicio'] != null,
                  ),
                  _buildRegistroItem(
                    Icons.restaurant,
                    AppColors.warning,
                    'Descanso de Comida',
                    _jornada != null && _jornada!['hora_inicio_comida'] != null
                        ? '${_formatHora(_jornada!['hora_inicio_comida'])} - ${_formatHora(_jornada!['hora_fin_comida'])}'
                        : '--:--',
                    activo:
                        _jornada != null &&
                        _jornada!['hora_inicio_comida'] != null,
                  ),
                  _buildRegistroItem(
                    Icons.logout,
                    AppColors.textPrimary,
                    'Fin de Jornada',
                    _jornada != null
                        ? _formatHora(_jornada!['hora_fin'])
                        : '--:--',
                    activo: _jornada != null && _jornada!['hora_fin'] != null,
                  ),
                  const SizedBox(height: 16),

                  // Info inferior
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.secondary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Recuerda que debes realizar un descanso de al menos 30 minutos.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRegistroItem(
    IconData icono,
    Color color,
    String titulo,
    String hora, {
    bool activo = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activo ? color.withValues(alpha: 0.3) : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: activo
                  ? color.withValues(alpha: 0.1)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icono,
              color: activo
                  ? color
                  : AppColors.textPrimary.withValues(alpha: 0.3),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: activo
                    ? AppColors.textPrimary
                    : AppColors.textPrimary.withValues(alpha: 0.4),
              ),
            ),
          ),
          Text(
            hora,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: activo
                  ? AppColors.textPrimary
                  : AppColors.textPrimary.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
