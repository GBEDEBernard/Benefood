<?php

namespace Database\Factories;

use App\Models\NotificationTemplate;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<NotificationTemplate>
 */
class NotificationTemplateFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'event' => 'order.new_paid',
            'channel' => 'push',
            'subject' => 'Nouvelle commande {reference}',
            'body' => 'La commande {reference} a été confirmée et payée.',
            'is_active' => true,
        ];
    }
}
