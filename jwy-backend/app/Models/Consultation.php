<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\MorphOne;
use Illuminate\Database\Eloquent\SoftDeletes;

class Consultation extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'patient_id', 'medecin_id', 'dossier_medical_id', 'triage_ia_id',
        'type_consultation', 'symptomes', 'diagnostic', 'recommandations',
        'cout_consultation', 'statut', 'notes_consultation',
        'date_consultation', 'duree_minutes', 'note_patient', 'avis_patient',
    ];

    protected function casts(): array
    {
        return [
            'date_consultation' => 'datetime',
            'cout_consultation' => 'decimal:2',
            'note_patient'      => 'decimal:2',
        ];
    }

    // ─── Relations ───────────────────────────────────────────────────────────

    public function patient(): BelongsTo
    {
        return $this->belongsTo(Patient::class);
    }

    public function medecin(): BelongsTo
    {
        return $this->belongsTo(Medecin::class);
    }

    public function dossierMedical(): BelongsTo
    {
        return $this->belongsTo(DossierMedical::class, 'dossier_medical_id');
    }

    public function getEstPayeeAttribute(): bool
    {
        return Paiement::where('payable_type', self::class)
            ->where('payable_id', $this->id)
            ->where('statut', 'confirme')
            ->exists();
    }

    /** Pré-orientation IA à l'origine de la demande (facultative) */
    public function triageIa(): BelongsTo
    {
        return $this->belongsTo(TriageIA::class, 'triage_ia_id');
    }

    public function teleconsultation(): HasOne
    {
        return $this->hasOne(TeleConsultation::class);
    }

    public function consultationPhysique(): HasOne
    {
        return $this->hasOne(ConsultationPhysique::class);
    }

    public function prescriptions(): HasMany
    {
        return $this->hasMany(Prescription::class);
    }

    public function paiement(): MorphOne
    {
        return $this->morphOne(Paiement::class, 'payable');
    }

    // ─── Scopes ──────────────────────────────────────────────────────────────

    public function scopeEnAttente($query)
    {
        return $query->where('statut', 'en_attente');
    }

    public function scopeTerminee($query)
    {
        return $query->where('statut', 'terminee');
    }
}
