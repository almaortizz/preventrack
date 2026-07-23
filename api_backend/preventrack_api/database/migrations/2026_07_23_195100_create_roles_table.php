<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('roles', function (Blueprint $table) {
            $table->id();
            $table->string('nombre', 50)->unique();
            $table->string('descripcion', 150)->nullable();
            $table->timestamps();
        });

        DB::table('roles')->insert([
            ['nombre' => 'administrador', 'descripcion' => 'Gestiona todo el sistema desde el panel web', 'created_at' => now(), 'updated_at' => now()],
            ['nombre' => 'colaborador', 'descripcion' => 'Preventista y/o repartidor, opera desde la app móvil', 'created_at' => now(), 'updated_at' => now()],
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('roles');
    }
};
