<?php

namespace App\GraphQL\Mutations;

use App\Models\RendezVous;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class ReporterRendezVous
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): RendezVous
    {
        $user = $context->user();
        $rdv  = RendezVous::findOrFail($args['id']);

        abort_if(
            $user->patient?->id !== $rdv->patient_id && $user->medecin?->id !== $rdv->medecin_id,
            403
        );

        $rdv->update([
            'date_rendez_vous' => $args['nouvelle_date'],
            'statut'           => 'en_attente',
        ]);

        return $rdv;
    }
}
