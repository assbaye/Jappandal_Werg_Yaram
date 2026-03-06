<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\MorphOne;
use Illuminate\Database\Eloquent\SoftDeletes;

class Commande extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'patient_id', 'pharmacie_id', 'prescription_id', 'numero_commande',
        'statut', 'type_livraison', 'adresse_livraison',
        'montant_total', 'frais_livraison', 'notes',
    ];

    protected function casts(): array
    {
        return [
            'montant_total'  => 'decimal:2',
            'frais_livraison' => 'decimal:2',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Commande $c) {
            if (empty($c->numero_commande)) {
                $c->numero_commande = 'CMD-' . strtoupper(uniqid());
            }
        });
    }

    public function patient(): BelongsTo
    {
        return $this->belongsTo(Patient::class);
    }

    public function pharmacie(): BelongsTo
    {
        return $this->belongsTo(Pharmacie::class);
    }

    public function prescription(): BelongsTo
    {
        return $this->belongsTo(Prescription::class);
    }

    public function medicaments(): BelongsToMany
    {
        return $this->belongsToMany(Medicament::class, 'commande_medicament')
            ->withPivot('quantite', 'prix_unitaire')
            ->withTimestamps();
    }

    public function paiement(): MorphOne
    {
        return $this->morphOne(Paiement::class, 'payable');
    }
}
