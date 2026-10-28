<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Marca las jornadas que el sistema cerró solo por exceder el límite de horas
// (ver Jornada::HORAS_CIERRE_AUTOMATICO)
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('jornadas', function (Blueprint $table) {
            $table->boolean('cierre_automatico')->default(false)->after('hora_fin');
        });
    }

    public function down(): void
    {
        Schema::table('jornadas', function (Blueprint $table) {
            $table->dropColumn('cierre_automatico');
        });
    }
};
