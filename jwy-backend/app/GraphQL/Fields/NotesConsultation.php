<?php

namespace App\GraphQL\Fields;

use App\Models\Consultation;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

/**
 * Les notes de consultation sont privées : seul le médecin de la consultation les voit.
 */
class NotesConsultation
{
    public function __invoke(Consultation $consultation, array $args, GraphQLContext $context): ?string
    {
        $medecin = $context->user()?->medecin;

        return $medecin && $medecin->id === $consultation->medecin_id
            ? $consultation->notes_consultation
            : null;
    }
}
