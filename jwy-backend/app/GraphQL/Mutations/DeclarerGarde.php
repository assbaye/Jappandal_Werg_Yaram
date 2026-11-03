<?php

namespace App\GraphQL\Mutations;

use App\Models\Pharmacie;
use Carbon\Carbon;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class DeclarerGarde
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): Pharmacie
    {
        $pharmacie = $context->user()->pharmacien?->pharmacies()->first();

        if (! $pharmacie) {
            throw new Error('Aucune pharmacie rattachée à votre compte.');
        }

        $fin = null;
        if (! empty($args['jusqu_au'])) {
            // Saisie à l'heure locale de la pharmacie
            $fin = Carbon::parse($args['jusqu_au'], Pharmacie::FUSEAU);

            if ($fin->isPast()) {
                throw new Error('La fin de garde doit être dans le futur.');
            }
            if ($fin->gt(now()->addDays(8))) {
                throw new Error('Une garde dure au plus une semaine.');
            }
        }

        $pharmacie->update(['de_garde_jusqu_au' => $fin]);

        return $pharmacie->fresh();
    }
}
