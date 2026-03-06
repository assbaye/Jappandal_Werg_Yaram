<?php

namespace App\GraphQL\Mutations;

use App\Models\RendezVous;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class PrendreRendezVous
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): RendezVous
    {
        $user    = $context->user();
        $patient = $user->patient;

        abort_if(!$patient, 403, 'Seuls les patients peuvent prendre des rendez-vous.');

        return RendezVous::create([
            'patient_id'         => $patient->id,
            'medecin_id'         => $args['medecin_id'],
            'date_rendez_vous'   => $args['date_rendez_vous'],
            'duree_estimee'      => $args['duree_estimee'] ?? 30,
            'type_rendez_vous'   => $args['type_rendez_vous'],
            'motif'              => $args['motif'] ?? null,
            'lieu_rendez_vous'   => $args['lieu_rendez_vous'] ?? null,
            'statut'             => 'en_attente',
        ]);
    }
}
