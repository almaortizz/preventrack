<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ProductoController;
use App\Http\Controllers\CategoriaController;
use App\Http\Controllers\ClienteController;
use App\Http\Controllers\DomicilioController;
use App\Http\Controllers\VentaController;
use App\Http\Controllers\CotizacionController;
use App\Http\Controllers\DevolucionController;
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

// -----------------------------------------------------------------
// Rutas protegidas (requieren token Sanctum)
// -----------------------------------------------------------------
Route::middleware('auth:sanctum')->group(function () {

    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);

    Route::apiResource('productos', ProductoController::class);
    Route::apiResource('categorias', CategoriaController::class);
    Route::apiResource('clientes', ClienteController::class);

    Route::get('clientes/{cliente}/domicilios', [DomicilioController::class, 'index']);
    Route::post('clientes/{cliente}/domicilios', [DomicilioController::class, 'store']);
    Route::get('domicilios/{domicilio}', [DomicilioController::class, 'show']);
    Route::put('domicilios/{domicilio}', [DomicilioController::class, 'update']);
    Route::delete('domicilios/{domicilio}', [DomicilioController::class, 'destroy']);

    Route::apiResource('ventas', VentaController::class)->except(['destroy']);
    Route::delete('ventas/{venta}', [VentaController::class, 'destroy']);

    Route::post('ventas/{venta}/asignar-entrega', [VentaController::class, 'asignarEntrega']);
    Route::post('ventas/{venta}/marcar-entregado', [VentaController::class, 'marcarEntregado']);
    Route::post('ventas/{venta}/marcar-no-entregado', [VentaController::class, 'marcarNoEntregado']);
    Route::post('ventas/{venta}/cancelar', [VentaController::class, 'cancelar']);
    Route::post('ventas/{venta}/marcar-impreso', [VentaController::class, 'marcarImpreso']);

    Route::apiResource('cotizaciones', CotizacionController::class)->except(['destroy']);
    Route::delete('cotizaciones/{cotizacion}', [CotizacionController::class, 'destroy']);
    Route::post('cotizaciones/{cotizacion}/convertir', [CotizacionController::class, 'convertir']);

    Route::apiResource('devoluciones', DevolucionController::class)->only(['index', 'store', 'show', 'destroy']);
    Route::apiResource('visitas', VisitaController::class)->only(['index', 'store', 'show', 'destroy']);

    Route::get('jornadas', [JornadaController::class, 'index']);
    Route::get('jornadas/{jornada}', [JornadaController::class, 'show']);
    Route::post('jornadas/iniciar', [JornadaController::class, 'iniciar']);
    Route::post('jornadas/{jornada}/iniciar-comida', [JornadaController::class, 'iniciarComida']);
    Route::post('jornadas/{jornada}/finalizar-comida', [JornadaController::class, 'finalizarComida']);
    Route::post('jornadas/{jornada}/finalizar', [JornadaController::class, 'finalizar']);

    Route::apiResource('cuotas', CuotaController::class);

    Route::apiResource('rutas', RutaController::class)->only(['index', 'store', 'show', 'destroy']);
    Route::post('rutas/{ruta}/reordenar', [RutaController::class, 'reordenar']);
    Route::post('rutas/{ruta}/visitar/{detalleRutaId}', [RutaController::class, 'marcarVisitada']);

    Route::get('comisiones', [ComisionController::class, 'index']);
    Route::get('comisiones/{comision}', [ComisionController::class, 'show']);
    Route::post('cuotas/{cuota}/evaluar', [ComisionController::class, 'evaluarCuota']);
    Route::post('comisiones/{comision}/marcar-pagada', [ComisionController::class, 'marcarPagada']);
    Route::get('reportes/ventas', [ReporteController::class, 'ventas']);

    Route::get('reportes/clientes', [ReporteController::class, 'clientes']);
    Route::get('reportes/productos', [ReporteController::class, 'productos']);
    Route::get('reportes/jornadas', [ReporteController::class, 'jornadas']);
    Route::get('reportes/comisiones', [ReporteController::class, 'comisiones']);

    Route::post('usuarios/aceptar-terminos', [UsuarioController::class, 'aceptarTerminos']);
    Route::apiResource('usuarios', UsuarioController::class);
    Route::post('usuarios/{usuario}/bloquear', [UsuarioController::class, 'bloquear']);
    Route::post('usuarios/{usuario}/desbloquear', [UsuarioController::class, 'desbloquear']);
    Route::post('usuarios/bloquear-todos', [UsuarioController::class, 'bloquearTodos']);

    Route::get('dashboard', [DashboardController::class, 'index']);

    // Aquí se irán agregando los recursos en los pasos siguientes:
    // productos, categorias, clientes, ventas, cotizaciones,
    // devoluciones, visitas, jornadas, rutas, comisiones, reportes...

});
