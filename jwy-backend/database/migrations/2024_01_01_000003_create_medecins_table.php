<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('medecins', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('numero_ordre')->unique();
            $table->string('nom');
            $table->string('prenom');
            $table->string('specialite');
            $table->string('hopital_rattachement')->nullable();
            $table->decimal('tarif_consultation', 10, 2)->default(15000);
            $table->jsonb('heures_disponibilite')->default('{}');
            $table->boolean('est_certifie')->default(false);
            $table->boolean('disponible_maintenant')->default(false);
            $table->string('photo')->nullable();
            $table->text('biographie')->nullable();
            $table->integer('annees_experience')->default(0);
            $table->decimal('note_moyenne', 3, 2)->default(0);
            $table->integer('nombre_consultations')->default(0);
            $table->timestamps();
            $table->softDeletes();

            $table->index('specialite');
            $table->index('disponible_maintenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('medecins');
    }
};
