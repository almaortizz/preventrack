<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ProductoController;
use App\Http\Controllers\CategoriaController;
use App\Http\Controllers\ClienteController;
use App\Http\Controllers\DomicilioController;
use App\Http\Controllers\VentaController;
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
    // Aquí se irán agregando los recursos en los pasos siguientes:
    // productos, categorias, clientes, ventas, cotizaciones,
    // devoluciones, visitas, jornadas, rutas, comisiones, reportes...

});
