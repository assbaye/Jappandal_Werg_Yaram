<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class DossierMedical extends Model
{
    use HasFactory;

    protected $table = 'dossiers_medicaux';

    protected $fillable = [
        'patient_id', 'antecedents_medicaux', 'allergies_connues',
        'medicaments_actuels', 'groupe_sanguin', 'poids', 'taille', 'notes_generales',
    ];

    protected function casts(): array
    {
        return [
            'allergies_connues'   => 'array',
            'medicaments_actuels' => 'array',
            'poids'               => 'decimal:2',
            'taille'              => 'decimal:2',
        ];
    }

    public function patient(): BelongsTo
    {
        return $this->belongsTo(Patient::class);
    }

    public function consultations(): HasMany
    {
        return $this->hasMany(Consultation::class, 'dossier_medical_id');
    }

    public function prescriptions(): HasMany
    {
        return $this->hasMany(Prescription::class, 'patient_id', 'patient_id');
    }

    public function getImcAttribute(): ?float
    {
        if ($this->poids && $this->taille && $this->taille > 0) {
            $tailleMetres = $this->taille / 100;
            return round($this->poids / ($tailleMetres * $tailleMetres), 1);
        }
        return null;
    }
}
