<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Facture extends Model
{
    use HasFactory;

    protected $fillable = [
        'paiement_id', 'numero_facture', 'date_emission', 'date_echeance',
        'montant_ht', 'tva', 'montant_ttc', 'statut', 'pdf_url',
    ];

    protected function casts(): array
    {
        return [
            'date_emission' => 'datetime',
            'date_echeance' => 'datetime',
            'montant_ht'    => 'decimal:2',
            'tva'           => 'decimal:2',
            'montant_ttc'   => 'decimal:2',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Facture $f) {
            if (empty($f->numero_facture)) {
                $f->numero_facture = 'FAC-' . date('Y') . '-' . strtoupper(uniqid());
            }
            if (empty($f->date_emission)) {
                $f->date_emission = now();
            }
        });
    }

    public function paiement(): BelongsTo
    {
        return $this->belongsTo(Paiement::class);
    }
}
