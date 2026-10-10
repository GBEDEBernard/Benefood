<?php

namespace App\Services;

use App\Jobs\SendPushNotifications;
use App\Models\Notification;
use App\Models\NotificationTemplate;
use App\Models\Order;
use App\Models\User;
use App\Models\Vendor;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Str;

/**
 * Notifications applicatives (J124, J33 §3) : un événement, un modèle de
 * notification, une ligne par destinataire dans la table `notifications`.
 *
 * Chaque notification porte dans `data` un écran cible et / ou un identifiant
 * de commande : le mobile s'en sert pour ouvrir le détail correspondant
 * (deep-link) et les push FCM transportent les mêmes clés (J24).
 */
class NotificationService
{
    /**
     * Émet une notification pour un événement donné vers des destinataires.
     *
     * Les destinataires sont des modèles User (dédupliqués par id). Pour les
     * vendeurs, les préférences de notifications de la boutique sont
     * respectées (notify_new_orders, notify_cancellations, notify_payments).
     *
     * @param  array<int, User|null>  $recipients
     * @param  array<string, mixed>  $data
     */
    public function notifyEvent(string $event, array $recipients, array $data = []): void
    {
        $template = NotificationTemplate::query()
            ->where('event', $event)
            ->where('channel', 'push')
            ->where('is_active', true)
            ->first();

        $recipients = $this->uniqueRecipients($recipients);

        foreach ($recipients as $user) {
            if ($this->prefersOff($event, $user)) {
                continue;
            }

            $payload = $this->payload($event, $data, $user);

            Notification::create([
                'user_id' => $user->id,
                'type' => $event,
                'title' => $template !== null ? $this->fill($template->subject ?: $template->event, $payload) : $event,
                'body' => $template !== null ? $this->fill($template->body, $payload) : null,
                'data' => $payload,
            ]);
        }

        if ($template === null || $recipients === [] || ! config('beninfood.push.enabled')) {
            return;
        }

        $users = array_values(array_filter($recipients, fn (User $user) => ! $this->prefersOff($event, $user)));

        if ($users === []) {
            return;
        }

        SendPushNotifications::dispatch(
            $event,
            $this->fill($template->subject ?: $template->event, $data),
            $this->fill($template->body, $data),
            $data,
            array_map(static fn (User $user): string => $user->id, $users),
        )->onQueue('push');
    }

    /**
     * Payload enrichi d'une notification : clés de navigation (order_id,
     * screen, deeplink) pour que le mobile ouvre le bon écran d'un seul tap.
     *
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function payload(string $event, array $data, User $user): array
    {
        $payload = $data + ['user_id' => $user->id];

        if (! isset($payload['order_id']) && ($data['order'] ?? null) instanceof Order) {
            $payload['order_id'] = $data['order']->id;
            $payload['reference'] = $data['order']->reference;
        }

        if (! isset($payload['screen']) && isset($payload['order_id'])) {
            $payload['screen'] = str_starts_with($event, 'order.') ? 'order_details' : null;
            if ($payload['screen'] === null) {
                unset($payload['screen']);
            }
        }

        if (isset($payload['order_id']) && ! isset($payload['deeplink'])) {
            $payload['deeplink'] = '/vendor/order/'.$payload['order_id'];
        }

        return $payload;
    }

    /**
     * Le destinataire a désactivé ce type de notification dans ses
     * préférences boutique ? (vendeurs uniquement)
     */
    private function prefersOff(string $event, User $user): bool
    {
        $vendor = Vendor::query()->where('user_id', $user->id)->first();

        if ($vendor === null) {
            return false;
        }

        $settings = $vendor->settings()->first();

        if ($settings === null) {
            return false;
        }

        return match ($event) {
            'order.paid' => ! $settings->notify_new_orders,
            'order.accepted' => ! $settings->notify_new_orders,
            'order.cancelled', 'order.refunded', 'order.refund_initiated' => ! $settings->notify_cancellations,
            'order.delivered' => ! $settings->notify_payments,
            default => false,
        };
    }

    /**
     * Utilisateurs de la porteuse (porteuse + admin technique) pour le suivi
     * des réclamations et des remboursements.
     *
     * @return Collection<int, User>
     */
    public function porteuseUsers(): Collection
    {
        $slugs = ['porteuse', 'admin-technique'];

        return User::query()
            ->whereHas('roles', fn ($query) => $query->whereIn('slug', $slugs))
            ->get();
    }

    /**
     * @param  array<int, User|null>  $recipients
     * @return array<int, User>
     */
    private function uniqueRecipients(array $recipients): array
    {
        $unique = [];

        foreach ($recipients as $recipient) {
            if ($recipient instanceof User && ! isset($unique[$recipient->id])) {
                $unique[$recipient->id] = $recipient;
            }
        }

        return array_values($unique);
    }

    /**
     * Remplace les placeholders `{cle}` par les valeurs fournies.
     *
     * @param  array<string, mixed>  $data
     */
    private function fill(string $text, array $data): string
    {
        foreach ($data as $key => $value) {
            if (is_scalar($value) || $value === null) {
                $text = Str::replace('{'.$key.'}', (string) $value, $text);
            }
        }

        return $text;
    }
}
