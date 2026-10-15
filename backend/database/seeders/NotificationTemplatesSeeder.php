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
                'subject' => 'Commande reçue',
                'body' => 'Nouvelle commande #{reference} à préparer.',
            ],
            [
                'event' => 'order.accepted',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Commande acceptée',
                'body' => 'Votre commande #{reference} a été acceptée.',
            ],
            [
                'event' => 'order.delivered',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Commande livrée',
                'body' => 'Votre commande #{reference} a été livrée.',
            ],
            [
                'event' => 'delivery.offered',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Nouvelle course disponible',
                'body' => 'Nouvelle course #{reference} disponible.',
            ],
            [
                'event' => 'order.cancelled',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Commande annulée',
                'body' => 'Votre commande #{reference} a été annulée.',
            ],
            [
                'event' => 'order.refund_initiated',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Remboursement en cours',
                'body' => 'Un remboursement de {amount} FCFA est en cours pour la commande #{reference}.',
            ],
            [
                'event' => 'order.refunded',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Remboursement effectué',
                'body' => 'Votre commande #{reference} a été remboursée ({amount} FCFA).',
            ],
            [
                'event' => 'parcel.delivered',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Colis livré',
                'body' => 'Votre colis #{reference} a été livré.',
            ],
            [
                'event' => 'parcel.refund_initiated',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Remboursement du colis en cours',
                'body' => 'Le remboursement de votre colis #{reference} ({amount} F CFA) est en cours.',
            ],
            [
                'event' => 'parcel.refunded',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Colis remboursé',
                'body' => 'Votre colis #{reference} a été remboursé ({amount} F CFA).',
            ],
            [
                'event' => 'complaint.opened',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Nouvelle réclamation',
                'body' => 'Nouvelle réclamation : {subject}.',
            ],
            [
                'event' => 'complaint.message',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Nouveau message sur la réclamation',
                'body' => 'Nouveau message sur la réclamation « {subject} ».',
            ],
            [
                'event' => 'complaint.resolved',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Réclamation traitée',
                'body' => 'Votre réclamation « {subject} » a été traitée.',
            ],
            [
                'event' => 'driver.favorite.requested',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Nouvelle demande de favori',
                'body' => '{reference} souhaite vous ajouter à ses livreurs favoris.',
            ],
            [
                'event' => 'driver.favorite.accepted',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Livreur favori ajouté',
                'body' => '{reference} a accepté de devenir votre livreur favori.',
            ],
            [
                'event' => 'parcel.offered',
                'channel' => NotificationTemplateChannel::Push->value,
                'subject' => 'Colis proposé',
                'body' => 'Un colis #{reference} vous est réservé.',
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
