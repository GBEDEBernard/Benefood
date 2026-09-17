<?php

namespace Database\Seeders;

use App\Enums\NotificationTemplateChannel;
use App\Models\NotificationTemplate;
use Illuminate\Database\Seeder;

class NotificationTemplatesSeeder extends Seeder
{
    /**
     * Modèles de notification initiaux (J33 §3).
     */
    public function run(): void
    {
        $templates = [
            [
                'event' => 'order.paid',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => null,
                'body' => 'Nouvelle commande #{reference} à préparer.',
            ],
            [
                'event' => 'order.accepted',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => null,
                'body' => 'Votre commande #{reference} a été acceptée.',
            ],
            [
                'event' => 'order.delivered',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => null,
                'body' => 'Votre commande #{reference} a été livrée.',
            ],
            [
                'event' => 'delivery.offered',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => null,
                'body' => 'Nouvelle course #{reference} disponible.',
            ],
            [
                'event' => 'order.cancelled',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => null,
                'body' => 'Votre commande #{reference} a été annulée.',
            ],
            [
                'event' => 'order.refund_initiated',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => null,
                'body' => 'Un remboursement de {amount} FCFA est en cours pour la commande #{reference}.',
            ],
            [
                'event' => 'order.refunded',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => null,
                'body' => 'Votre commande #{reference} a été remboursée ({amount} FCFA).',
            ],
            [
                'event' => 'complaint.opened',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => null,
                'body' => 'Nouvelle réclamation : {subject}.',
            ],
            [
                'event' => 'complaint.message',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => null,
                'body' => 'Nouveau message sur la réclamation « {subject} ».',
            ],
            [
                'event' => 'complaint.resolved',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => null,
                'body' => 'Votre réclamation « {subject} » a été traitée.',
            ],
        ];

        foreach ($templates as $template) {
            NotificationTemplate::updateOrCreate(
                ['event' => $template['event'], 'channel' => $template['channel']],
                [
                    'subject' => $template['subject'],
                    'body' => $template['body'],
                    'is_active' => true,
                ],
            );
        }
    }
}
