<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Pré-orientation des symptômes produite par l'assistant IA (cas d'utilisation UC16).
 * Ce n'est pas un diagnostic : elle oriente le patient et sert de résumé au médecin.
 */
class TriageIA extends Model
{
    protected $table = 'triages_ia';

    protected $fillable = [
        'patient_id', 'symptomes', 'niveau_urgence', 'specialite_recommandee',
        'type_consultation', 'resultat', 'modele', 'tokens_entree', 'tokens_sortie',
    ];

    protected function casts(): array
    {
        return ['resultat' => 'array'];
    }

    public function patient(): BelongsTo
    {
        return $this->belongsTo(Patient::class);
    }

    // Champs du résultat exposés directement dans GraphQL
    public function getExplicationAttribute(): string
    {
        return $this->resultat['explication'] ?? '';
    }

    public function getConseilsAttribute(): array
    {
        return $this->resultat['conseils'] ?? [];
    }

    public function getSignesAlerteAttribute(): array
    {
        return $this->resultat['signes_alerte'] ?? [];
    }

    public function getResumeMedecinAttribute(): string
    {
        return $this->resultat['resume_medecin'] ?? '';
    }
}
