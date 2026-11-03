<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class RendezVous extends Model
{
    use HasFactory, SoftDeletes;

    protected $table = 'rendez_vous';

    protected $fillable = [
        'patient_id', 'medecin_id', 'date_rendez_vous', 'duree_estimee',
        'statut', 'type_rendez_vous', 'lieu_rendez_vous', 'motif',
        'rappel_envoye', 'rappel_envoye_le',
    ];

    protected function casts(): array
    {
        return [
            'date_rendez_vous' => 'datetime',
            'rappel_envoye'    => 'boolean',
            'rappel_envoye_le' => 'datetime',
        ];
    }

    /**
     * Rendez-vous actifs d'un médecin qui chevauchent le créneau [début, début + durée[.
     */
    public function scopeChevauche($query, int $medecinId, string $debut, int $dureeMinutes, ?int $saufId = null)
    {
        $fin = \Carbon\Carbon::parse($debut)->addMinutes($dureeMinutes);

        return $query->where('medecin_id', $medecinId)
            ->whereNotIn('statut', ['annule', 'termine'])
            ->when($saufId, fn ($q) => $q->where('id', '!=', $saufId))
            ->where('date_rendez_vous', '<', $fin)
            ->whereRaw("date_rendez_vous + (duree_estimee || ' minutes')::interval > ?", [\Carbon\Carbon::parse($debut)]);
    }

    public function patient(): BelongsTo
    {
        return $this->belongsTo(Patient::class);
    }

    public function medecin(): BelongsTo
    {
        return $this->belongsTo(Medecin::class);
    }

    public function scopeAVenir($query)
    {
        return $query->where('date_rendez_vous', '>', now())
            ->whereIn('statut', ['en_attente', 'confirme'])
            ->orderBy('date_rendez_vous');
    }
}
