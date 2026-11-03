<?php

namespace App\Events;

use App\Models\NotificationJwy;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class NewNotification implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public readonly NotificationJwy $notification) {}

    public function broadcastOn(): Channel
    {
        return new Channel('user.' . $this->notification->user_id);
    }

    public function broadcastAs(): string
    {
        return 'new-notification';
    }

    public function broadcastWith(): array
    {
        return [
            'id'      => $this->notification->id,
            'titre'   => $this->notification->titre,
            'message' => $this->notification->message,
            'type'    => $this->notification->type,
        ];
    }
}
