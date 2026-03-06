<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TeleConsultation extends Model
{
    use HasFactory;

    protected $table = 'teleconsultations';

    protected $fillable = [
        'consultation_id', 'agora_channel', 'duree_consultation',
        'qualite_connexion', 'enregistrement_disponible',
        'enregistrement_url', 'debut_appel', 'fin_appel',
    ];

    protected function casts(): array
    {
        return [
            'enregistrement_disponible' => 'boolean',
            'debut_appel'               => 'datetime',
            'fin_appel'                 => 'datetime',
        ];
    }

    public function consultation(): BelongsTo
    {
        return $this->belongsTo(Consultation::class);
    }

    protected static function booted(): void
    {
        static::creating(function (TeleConsultation $tc) {
            if (empty($tc->agora_channel)) {
                $tc->agora_channel = 'jwy-' . uniqid();
            }
        });
    }
}
