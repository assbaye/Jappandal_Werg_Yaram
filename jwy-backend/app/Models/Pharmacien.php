<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Pharmacien extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = ['user_id', 'numero_ordre', 'nom', 'prenom', 'photo'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function pharmacies(): BelongsToMany
    {
        return $this->belongsToMany(Pharmacie::class, 'pharmacie_pharmacien')
            ->withPivot('est_responsable')
            ->withTimestamps();
    }

    public function getNomCompletAttribute(): string
    {
        return "{$this->prenom} {$this->nom}";
    }
}
