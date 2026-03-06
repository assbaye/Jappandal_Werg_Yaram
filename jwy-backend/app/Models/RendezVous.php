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
