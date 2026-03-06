<?php

namespace App\GraphQL\Subscriptions;

use App\Models\Consultation;
use Illuminate\Http\Request;
use Nuwave\Lighthouse\Schema\Types\GraphQLSubscription;
use Nuwave\Lighthouse\Subscriptions\Subscriber;

class StatutConsultation extends GraphQLSubscription
{
    /**
     * Check if subscriber is allowed to listen to the subscription.
     */
    public function authorize(Subscriber $subscriber, Request $request): bool
    {
        $user = $subscriber->context->user();
        if (!$user) {
            return false;
        }

        $consultationId = $subscriber->args['consultation_id'];
        $consultation   = Consultation::find($consultationId);

        if (!$consultation) {
            return false;
        }

        // Seuls le patient et le médecin concernés peuvent s'abonner
        return $user->id === $consultation->patient?->user_id
            || $user->id === $consultation->medecin?->user_id;
    }

    /**
     * Filter which subscribers should receive the subscription payload.
     */
    public function filter(Subscriber $subscriber, mixed $root): bool
    {
        return (string) $root->id === (string) $subscriber->args['consultation_id'];
    }
}
