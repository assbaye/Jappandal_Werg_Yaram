<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ConsultationPhysique extends Model
{
    protected $table = 'consultations_physiques';

    protected $fillable = [
        'consultation_id', 'adresse_consultation',
        'salle_consultation', 'presence_confirmee',
    ];

    protected function casts(): array
    {
        return ['presence_confirmee' => 'boolean'];
    }

    public function consultation(): BelongsTo
    {
        return $this->belongsTo(Consultation::class);
    }
}
