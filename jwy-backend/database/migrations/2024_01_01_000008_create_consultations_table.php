<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('consultations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('patient_id')->constrained()->restrictOnDelete();
            $table->foreignId('medecin_id')->constrained()->restrictOnDelete();
            $table->foreignId('dossier_medical_id')->nullable()->constrained('dossiers_medicaux')->nullOnDelete();
            $table->enum('type_consultation', ['video', 'chat', 'physique', 'differee'])->default('video');
            $table->text('symptomes')->nullable();
            $table->text('diagnostic')->nullable();
            $table->text('recommandations')->nullable();
            $table->decimal('cout_consultation', 10, 2)->default(0);
            $table->enum('statut', [
                'en_attente',
                'confirmee',
                'en_cours',
                'terminee',
                'annulee',
                'no_show'
            ])->default('en_attente');
            $table->text('notes_consultation')->nullable();
            $table->timestamp('date_consultation')->nullable();
            $table->integer('duree_minutes')->nullable();
            $table->decimal('note_patient', 3, 2)->nullable();
            $table->text('avis_patient')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['patient_id', 'statut']);
            $table->index(['medecin_id', 'statut']);
            $table->index('date_consultation');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('consultations');
    }
};
