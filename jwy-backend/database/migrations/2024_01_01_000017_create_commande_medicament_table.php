<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('commande_medicament', function (Blueprint $table) {
            $table->id();
            $table->foreignId('commande_id')->constrained()->cascadeOnDelete();
            $table->foreignId('medicament_id')->constrained()->restrictOnDelete();
            $table->integer('quantite')->default(1);
            $table->decimal('prix_unitaire', 10, 2);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('commande_medicament');
    }
};
