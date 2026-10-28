<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ProductoController;
use App\Http\Controllers\CategoriaController;
use App\Http\Controllers\ClienteController;
use App\Http\Controllers\DomicilioController;
use App\Http\Controllers\VentaController;
use App\Http\Controllers\VisitaController;
use App\Http\Controllers\JornadaController;
use App\Http\Controllers\CuotaController;
use App\Http\Controllers\RutaController;
use App\Http\Controllers\ComisionController;
use App\Http\Controllers\ReporteController;
use App\Http\Controllers\UsuarioController;
use App\Http\Controllers\DashboardController;

// -----------------------------------------------------------------
// Rutas públicas (sin autenticación)
// -----------------------------------------------------------------
Route::post('/login', [AuthController::class, 'login']);

// Imágenes de productos (las entrega el propio API para que la app móvil
// no dependa del enlace simbólico public/storage).
Route::get('/imagenes/{path}', function (string $path) {
    abort_unless(str_starts_with($path, 'productos/'), 404);
    abort_unless(\Illuminate\Support\Facades\Storage::disk('public')->exists($path), 404);

    return \Illuminate\Support\Facades\Storage::disk('public')->response($path);
})->where('path', '.*');

// -----------------------------------------------------------------
// Rutas protegidas (requieren token Sanctum)
// -----------------------------------------------------------------
Route::middleware('auth:sanctum')->group(function () {

    // ─────────────────────────────────────────────────────────────
    // Uso de la app (cualquier usuario con sesión). Los datos se filtran
    // por usuario en cada controlador (cada preventista ve lo suyo).
    // ─────────────────────────────────────────────────────────────

    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('usuarios/aceptar-terminos', [UsuarioController::class, 'aceptarTerminos']);
    Route::post('/ubicacion', [UsuarioController::class, 'actualizarUbicacion']);

    // Catálogo (consulta)
    Route::apiResource('productos', ProductoController::class)->only(['index', 'show']);
    Route::apiResource('categorias', CategoriaController::class)->only(['index', 'show']);

    // Clientes: consultar y registrar
    Route::apiResource('clientes', ClienteController::class)->only(['index', 'show', 'store']);
    Route::get('clientes/{cliente}/domicilios', [DomicilioController::class, 'index']);
    Route::post('clientes/{cliente}/domicilios', [DomicilioController::class, 'store']);
    Route::get('domicilios/{domicilio}', [DomicilioController::class, 'show']);

    // Pedidos (antes de ventas/{venta} para que no se confundan)
    Route::get('ventas/ultimo-folio', [VentaController::class, 'ultimoFolio']);
    Route::apiResource('ventas', VentaController::class)->only(['index', 'show', 'store']);
    Route::post('ventas/{venta}/marcar-entregado', [VentaController::class, 'marcarEntregado']);
    Route::post('ventas/{venta}/marcar-no-entregado', [VentaController::class, 'marcarNoEntregado']);
    Route::post('ventas/{venta}/marcar-impreso', [VentaController::class, 'marcarImpreso']);

    // Jornada (antes de jornadas/{jornada})
    Route::get('jornadas', [JornadaController::class, 'index']);
    Route::get('jornadas/actual', [JornadaController::class, 'actual']);
    Route::post('jornadas/registrar', [JornadaController::class, 'registrar']);
    Route::get('jornadas/{jornada}', [JornadaController::class, 'show']);

    // Rutas de visita / entrega
    Route::get('ruta-del-dia', [DashboardController::class, 'rutaDelDia']);
    Route::post('rutas/{ruta}/visitar/{detalleRutaId}', [RutaController::class, 'marcarVisitada']);

    // Inicio del preventista y sus comisiones
    Route::get('dashboard', [DashboardController::class, 'index']);
    Route::get('comisiones', [ComisionController::class, 'index']);

    // ─────────────────────────────────────────────────────────────
    // Administración (panel web y supervisión): solo administrador
    // ─────────────────────────────────────────────────────────────
    Route::middleware('admin')->group(function () {

        Route::get('/dashboard-admin', [DashboardController::class, 'dashboardAdmin']);
        Route::get('/monitoreo', [\App\Http\Controllers\MonitoreoController::class, 'index']);

        Route::apiResource('productos', ProductoController::class)->except(['index', 'show']);
        Route::apiResource('categorias', CategoriaController::class)->except(['index', 'show']);

        // Clientes: editar y activar / desactivar (ya no se borran)
        Route::put('clientes/{cliente}', [ClienteController::class, 'update']);
        Route::put('domicilios/{domicilio}', [DomicilioController::class, 'update']);
        Route::delete('domicilios/{domicilio}', [DomicilioController::class, 'destroy']);

        // Pedidos (ya no se borran: se cancelan)
        Route::put('ventas/{venta}', [VentaController::class, 'update']);
        Route::post('ventas/{venta}/asignar-entrega', [VentaController::class, 'asignarEntrega']);
        Route::post('ventas/{venta}/cancelar', [VentaController::class, 'cancelar']);
        Route::get('ventas/{venta}/remision', [\App\Http\Controllers\RemisionController::class, 'generar']);
        Route::get('ventas/{venta}/remision-excel', [\App\Http\Controllers\RemisionController::class, 'excel']);

        Route::apiResource('visitas', VisitaController::class)->only(['index', 'store', 'show', 'destroy']);

        // Rutas antiguas de jornada (la app usa jornadas/registrar)
        Route::post('jornadas/iniciar', [JornadaController::class, 'iniciar']);
        Route::post('jornadas/{jornada}/iniciar-comida', [JornadaController::class, 'iniciarComida']);
        Route::post('jornadas/{jornada}/finalizar-comida', [JornadaController::class, 'finalizarComida']);
        Route::post('jornadas/{jornada}/finalizar', [JornadaController::class, 'finalizar']);

        Route::post('cuotas/lote', [CuotaController::class, 'lote']);
        Route::apiResource('cuotas', CuotaController::class);
        Route::post('cuotas/{cuota}/evaluar', [ComisionController::class, 'evaluarCuota']);
        Route::get('comisiones/{comision}', [ComisionController::class, 'show']);
        Route::post('comisiones/{comision}/marcar-pagada', [ComisionController::class, 'marcarPagada']);

        Route::apiResource('rutas', RutaController::class)->only(['index', 'store', 'show', 'destroy']);
        Route::post('rutas/{ruta}/reordenar', [RutaController::class, 'reordenar']);

        Route::get('reportes/ventas', [ReporteController::class, 'ventas']);
        Route::get('reportes/hoja-pedidos', [ReporteController::class, 'hojaPedidosDia']);
        Route::get('reportes/clientes', [ReporteController::class, 'clientes']);
        Route::get('reportes/productos', [ReporteController::class, 'productos']);
        Route::get('reportes/jornadas', [ReporteController::class, 'jornadas']);
        Route::get('reportes/comisiones', [ReporteController::class, 'comisiones']);

        Route::apiResource('usuarios', UsuarioController::class);
        Route::post('usuarios/{usuario}/bloquear', [UsuarioController::class, 'bloquear']);
        Route::post('usuarios/{usuario}/desbloquear', [UsuarioController::class, 'desbloquear']);
        Route::post('usuarios/bloquear-todos', [UsuarioController::class, 'bloquearTodos']);
    });
});
