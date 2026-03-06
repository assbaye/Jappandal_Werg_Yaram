<?php

namespace App\GraphQL\Mutations;

use App\Models\Consultation;
use App\Services\AgoraService;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class DemarrerTeleConsultation
{
    public function __construct(private AgoraService $agora) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): array
    {
        $user = $context->user();
        $consultation = Consultation::with('teleconsultation')->findOrFail($args['consultation_id']);

        // Vérifier que l'utilisateur est le patient ou le médecin de cette consultation
        $authorized = match ($user->role) {
            'patient' => $consultation->patient->user_id === $user->id,
            'medecin' => $consultation->medecin->user_id === $user->id,
            default   => false,
        };

        if (! $authorized) {
            throw new Error('Accès non autorisé à cette consultation.');
        }

        if (! $consultation->teleconsultation) {
            throw new Error('Cette consultation n\'est pas une téléconsultation.');
        }

        $tc = $consultation->teleconsultation;
        $role = $user->role === 'medecin' ? AgoraService::ROLE_PUBLISHER : AgoraService::ROLE_SUBSCRIBER;

        $token = $this->agora->generateToken(
            channel: $tc->agora_channel,
            userId: (string) $user->id,
            role: $role
        );

        // Marquer la consultation comme en cours si elle est confirmée
        if ($consultation->statut === 'confirmee') {
            $consultation->update(['statut' => 'en_cours']);
            if (! $tc->debut_appel) {
                $tc->update(['debut_appel' => now()]);
            }
        }

        return [
            'agora_channel' => $tc->agora_channel,
            'agora_token'   => $token,
            'agora_app_id'  => config('services.agora.app_id'),
            'consultation'  => $consultation,
        ];
    }
}
