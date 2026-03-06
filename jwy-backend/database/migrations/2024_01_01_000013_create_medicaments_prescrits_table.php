<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('medicaments_prescrits', function (Blueprint $table) {
            $table->id();
            $table->foreignId('prescription_id')->constrained()->cascadeOnDelete();
            $table->foreignId('medicament_id')->constrained()->restrictOnDelete();
            $table->integer('quantite')->default(1);
            $table->string('posologie');
            $table->integer('duree_traitement')->default(7);
            $table->text('instructions_speciales')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('medicaments_prescrits');
    }
};
