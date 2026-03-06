<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('dossiers_medicaux', function (Blueprint $table) {
            $table->id();
            $table->foreignId('patient_id')->constrained()->cascadeOnDelete();
            $table->text('antecedents_medicaux')->nullable();
            $table->jsonb('allergies_connues')->default('[]');
            $table->jsonb('medicaments_actuels')->default('[]');
            $table->enum('groupe_sanguin', ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'])->nullable();
            $table->decimal('poids', 5, 2)->nullable();
            $table->decimal('taille', 5, 2)->nullable();
            $table->text('notes_generales')->nullable();
            $table->timestamps();

            $table->unique('patient_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dossiers_medicaux');
    }
};
