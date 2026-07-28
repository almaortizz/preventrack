<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ProductoController;
use App\Http\Controllers\CategoriaController;
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
    // Aquí se irán agregando los recursos en los pasos siguientes:
    // productos, categorias, clientes, ventas, cotizaciones,
    // devoluciones, visitas, jornadas, rutas, comisiones, reportes...

});
