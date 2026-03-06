<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('teleconsultations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('consultation_id')->unique()->constrained()->cascadeOnDelete();
            $table->string('agora_channel')->unique();
            $table->integer('duree_consultation')->nullable();
            $table->enum('qualite_connexion', ['excellente', 'bonne', 'moyenne', 'mauvaise'])->nullable();
            $table->boolean('enregistrement_disponible')->default(false);
            $table->string('enregistrement_url')->nullable();
            $table->timestamp('debut_appel')->nullable();
            $table->timestamp('fin_appel')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('teleconsultations');
    }
};
