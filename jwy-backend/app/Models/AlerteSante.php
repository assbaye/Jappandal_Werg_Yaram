<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AlerteSante extends Model
{
    use HasFactory;

    protected $table = 'alertes_sante';

    protected $fillable = [
        'created_by', 'type_alerte', 'zone', 'niveau_gravite',
        'description', 'recommandations', 'date_debut', 'date_fin',
        'est_active', 'personnes_touchees',
    ];

    protected function casts(): array
    {
        return [
            'date_debut'  => 'datetime',
            'date_fin'    => 'datetime',
            'est_active'  => 'boolean',
        ];
    }

    public function createur(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function scopeActive($query)
    {
        return $query->where('est_active', true);
    }
}
