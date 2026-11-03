<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Alerte d'urgence individuelle déclenchée par un patient (bouton SOS).
 * À distinguer d'AlerteSante, qui concerne la santé publique d'une zone.
 */
class AlerteUrgence extends Model
{
    protected $table = 'alertes_urgence';

    protected $fillable = [
        'patient_id', 'medecin_id', 'type_urgence', 'description',
        'latitude', 'longitude', 'statut', 'prise_en_charge_le', 'cloturee_le',
    ];

    protected function casts(): array
    {
        return [
            'latitude'           => 'float',
            'longitude'          => 'float',
            'prise_en_charge_le' => 'datetime',
            'cloturee_le'        => 'datetime',
        ];
    }

    public function patient(): BelongsTo
    {
        return $this->belongsTo(Patient::class);
    }

    public function medecin(): BelongsTo
    {
        return $this->belongsTo(Medecin::class);
    }

    public function scopeEnCours($query)
    {
        return $query->whereIn('statut', ['active', 'prise_en_charge']);
    }
}
