<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pharmacie_pharmacien', function (Blueprint $table) {
            $table->foreignId('pharmacie_id')->constrained()->cascadeOnDelete();
            $table->foreignId('pharmacien_id')->constrained()->cascadeOnDelete();
            $table->boolean('est_responsable')->default(false);
            $table->timestamps();

            $table->primary(['pharmacie_id', 'pharmacien_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pharmacie_pharmacien');
    }
};
