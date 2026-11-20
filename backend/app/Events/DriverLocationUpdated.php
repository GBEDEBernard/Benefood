<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Position livreur prête à être diffusée sur une mission active.
 *
 * L'événement est toujours émis côté serveur, mais la diffusion effective est
 * désactivée par défaut : l'app mobile continue de s'appuyer sur FCM + polling.
 * Le canal privé et le nom de diffusion sont déjà ceux d'une future activation
 * Reverb, sans installer de serveur WebSocket aujourd'hui.
 */
class DriverLocationUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * @param  array<string, mixed>  $position
     */
    public function __construct(
        public readonly string $deliveryId,
        public readonly string $driverProfileId,
        public readonly ?string $clientUserId,
        public readonly array $position,
    ) {}

    /**
     * @return array<int, Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('delivery.'.$this->deliveryId),
        ];
    }

    public function broadcastAs(): string
    {
        return 'driver.location.updated';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'delivery_id' => $this->deliveryId,
            'driver_profile_id' => $this->driverProfileId,
            'position' => $this->position,
        ];
    }

    public function broadcastWhen(): bool
    {
        return (bool) config('beninfood.tracking.broadcast_enabled', false);
    }
}
