<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('usuarios', function (Blueprint $table) {
            $table->decimal('ultima_latitud', 10, 7)->nullable()->after('color');
            $table->decimal('ultima_longitud', 10, 7)->nullable()->after('ultima_latitud');
            $table->dateTime('ultima_ubicacion_at')->nullable()->after('ultima_longitud');
        });
    }

    public function down(): void
    {
        Schema::table('usuarios', function (Blueprint $table) {
            $table->dropColumn(['ultima_latitud', 'ultima_longitud', 'ultima_ubicacion_at']);
        });
    }
};
