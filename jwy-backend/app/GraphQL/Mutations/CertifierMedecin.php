<?php

namespace App\GraphQL\Mutations;

use App\Models\Medecin;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class CertifierMedecin
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): Medecin
    {
        abort_if(!$context->user()->hasRole('admin'), 403);

        $medecin = Medecin::findOrFail($args['medecin_id']);
        $medecin->update(['est_certifie' => !$medecin->est_certifie]);

        return $medecin->fresh();
    }
}
