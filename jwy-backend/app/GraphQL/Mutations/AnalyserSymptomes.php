<?php

namespace App\GraphQL\Mutations;

use App\Models\TriageIA;
use App\Services\TriageService;
use GraphQL\Error\Error;
use Illuminate\Support\Facades\RateLimiter;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class AnalyserSymptomes
{
    public function __construct(private TriageService $triage) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): TriageIA
    {
        $patient = $context->user()->patient;

        if (! $patient) {
            throw new Error('L\'analyse des symptômes est réservée aux patients.');
        }

        // Limite par patient et par heure : chaque analyse est facturée par Anthropic
        $cle = 'triage-ia:' . $patient->id;
        $max = config('services.anthropic.triages_par_heure');
        if (RateLimiter::tooManyAttempts($cle, $max)) {
            $minutes = (int) ceil(RateLimiter::availableIn($cle) / 60);
            throw new Error("Vous avez atteint la limite de {$max} analyses par heure. Réessayez dans {$minutes} min.");
        }
        $triage = $this->triage->analyser($patient, trim($args['symptomes']));
        RateLimiter::hit($cle, 3600); // seules les analyses abouties comptent

        return $triage;
    }
}
