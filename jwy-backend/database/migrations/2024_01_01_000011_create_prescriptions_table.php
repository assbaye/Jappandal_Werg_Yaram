<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('prescriptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('consultation_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('medecin_id')->constrained()->restrictOnDelete();
            $table->foreignId('patient_id')->constrained()->restrictOnDelete();
            $table->integer('validite_jours')->default(30);
            $table->text('instructions')->nullable();
            $table->boolean('est_executee')->default(false);
            $table->timestamp('date_execution')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['patient_id', 'est_executee']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('prescriptions');
    }
};
