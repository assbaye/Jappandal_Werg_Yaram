<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Historique des pré-orientations IA : traçabilité médicale et suivi des coûts
        Schema::create('triages_ia', function (Blueprint $table) {
            $table->id();
            $table->foreignId('patient_id')->constrained('patients')->cascadeOnDelete();
            $table->text('symptomes');
            $table->string('niveau_urgence');
            $table->string('specialite_recommandee');
            $table->string('type_consultation')->nullable();
            $table->json('resultat');
            $table->string('modele');
            $table->unsignedInteger('tokens_entree')->default(0);
            $table->unsignedInteger('tokens_sortie')->default(0);
            $table->timestamps();
        });

        Schema::table('consultations', function (Blueprint $table) {
            $table->foreignId('triage_ia_id')->nullable()->after('dossier_medical_id')
                ->constrained('triages_ia')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('consultations', function (Blueprint $table) {
            $table->dropConstrainedForeignId('triage_ia_id');
        });
        Schema::dropIfExists('triages_ia');
    }
};
