<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stocks_medicaments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('pharmacie_id')->constrained()->cascadeOnDelete();
            $table->foreignId('medicament_id')->constrained()->cascadeOnDelete();
            $table->integer('quantite_disponible')->default(0);
            $table->integer('quantite_minimale')->default(10);
            $table->date('date_expiration')->nullable();
            $table->decimal('prix_vente', 10, 2);
            $table->string('emplacement_stock')->nullable();
            $table->timestamps();

            $table->unique(['pharmacie_id', 'medicament_id']);
            $table->index(['quantite_disponible']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stocks_medicaments');
    }
};
