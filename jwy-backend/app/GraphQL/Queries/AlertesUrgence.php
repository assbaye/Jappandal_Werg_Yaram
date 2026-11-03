<?php

namespace App\GraphQL\Queries;

use App\Models\AlerteUrgence;
use GraphQL\Error\Error;
use Illuminate\Database\Eloquent\Collection;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class AlertesUrgence
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): Collection
    {
        $medecin = $context->user()->medecin;

        if (! $medecin) {
            throw new Error('Accès réservé aux médecins.');
        }

        // Alertes libres + celles dont je m'occupe (et mes 10 dernières terminées)
        $enCours = AlerteUrgence::with(['patient', 'medecin'])
            ->where(fn ($q) => $q->where('statut', 'active')
                ->orWhere(fn ($q) => $q->where('statut', 'prise_en_charge')->where('medecin_id', $medecin->id)))
            ->oldest()
            ->get();

        $terminees = AlerteUrgence::with(['patient', 'medecin'])
            ->where('medecin_id', $medecin->id)
            ->whereIn('statut', ['cloturee', 'annulee'])
            ->latest('cloturee_le')
            ->limit(10)
            ->get();

        return $enCours->concat($terminees);
    }
}
