import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/ubicacion_service.dart';
import 'dashboard_screen.dart';
import 'dashboard_admin_screen.dart';
import 'clientes_screen.dart';
import 'pedidos_screen.dart';
import 'entregas_screen.dart';
import 'jornada_screen.dart';
import 'perfil_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _reanudarUbicacionSiHayJornadaActiva();
  }

  // Si la persona cierra y vuelve a abrir la app mientras ya tenía una
  // jornada en curso, esto reactiva el reporte de ubicación en vivo
  // sin que tenga que volver a entrar a la pantalla de Jornada Laboral.
  Future<void> _reanudarUbicacionSiHayJornadaActiva() async {
    try {
      final result = await ApiService().get('jornadas');
      if (result['statusCode'] != 200) return;

      final data = result['data'];
      final jornadas = data is List ? data : (data['data'] ?? []);

      final hayActiva = jornadas.any(
        (j) => j['hora_inicio'] != null && j['hora_fin'] == null,
      );

      if (hayActiva) {
        UbicacionService.instancia.iniciar();
      }
    } catch (_) {
      // Si falla, no pasa nada grave: se reintentará la próxima vez
      // que se abra la pantalla de Jornada Laboral.
    }
  }

  bool _esAdmin(AuthProvider auth) {
    return auth.usuario?['rol_id'] == 1;
  }

  List<Widget> _getScreens(bool admin) {
    if (admin) {
      return [
        DashboardAdminScreen(),
        ClientesScreen(),
        PedidosScreen(),
        EntregasScreen(),
      ];
    }
    return [
      DashboardScreen(onVerPedidos: () => setState(() => _selectedIndex = 2)),
      ClientesScreen(),
      PedidosScreen(),
      EntregasScreen(),
    ];
  }

  final List<String> _titles = const [
    'Preventrack',
    'Clientes',
    'Pedidos',
    'Entregas',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final nombre = auth.usuario?['nombre'] ?? 'U';
    final inicial = nombre[0].toUpperCase();
    final admin = _esAdmin(auth);
    final screens = _getScreens(admin);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        surfaceTintColor: AppColors.white,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.primary),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.secondary,
              child: Text(
                inicial,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.cardBorder.withValues(alpha: 0.5),
            height: 1,
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: AppColors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header del drawer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.cardBorder.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.secondary,
                      child: Text(
                        inicial,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          auth.usuario?['usuario'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary.withValues(alpha: 0.5),
                          ),
                        ),
                        if (admin) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Opciones
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                ),
                title: const Text('Mi perfil'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PerfilScreen()),
                  );
                },
              ),
              // Jornada laboral solo para colaboradores
              if (!admin)
                ListTile(
                  leading: const Icon(
                    Icons.access_time,
                    color: AppColors.primary,
                  ),
                  title: const Text('Jornada laboral'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JornadaScreen()),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Centro legal'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/legal');
                },
              ),
              const Spacer(),
              // Cerrar sesión
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.cardBorder.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    UbicacionService.instancia.detener();
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    await authProvider.logout();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: AppColors.primary),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart, color: AppColors.primary),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping, color: AppColors.primary),
            label: 'Entregas',
          ),
        ],
      ),
    );
  }
}
