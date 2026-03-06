<?php

namespace App\GraphQL\Subscriptions;

use Illuminate\Http\Request;
use Nuwave\Lighthouse\Schema\Types\GraphQLSubscription;
use Nuwave\Lighthouse\Subscriptions\Subscriber;

class NouvelleNotification extends GraphQLSubscription
{
    /**
     * Only authenticated users can subscribe.
     */
    public function authorize(Subscriber $subscriber, Request $request): bool
    {
        return $subscriber->context->user() !== null;
    }

    /**
     * Send notification only to the targeted user.
     */
    public function filter(Subscriber $subscriber, mixed $root): bool
    {
        $user = $subscriber->context->user();

        return $user && $root->user_id === $user->id;
    }
}
