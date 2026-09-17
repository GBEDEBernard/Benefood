<?php

namespace App\Services;

use App\Models\Notification;
use App\Models\NotificationTemplate;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Str;

/**
 * Notifications applicatives (J124, J33 §3) : un événement, un modèle de
 * notification, une ligne par destinataire dans la table `notifications`.
 */
class NotificationService
{
    /**
     * Émet une notification pour un événement donné vers des destinataires.
     *
     * Les destinataires sont des modèles User (dédupliqués par id).
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

        foreach ($this->uniqueRecipients($recipients) as $user) {
            $payload = $data + ['user_id' => $user->id];

            Notification::create([
                'user_id' => $user->id,
                'type' => $event,
                'title' => $template !== null ? $this->fill($template->subject ?: $template->event, $payload) : $event,
                'body' => $template !== null ? $this->fill($template->body, $payload) : null,
                'data' => $payload,
            ]);
        }
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
            $text = Str::replace('{'.$key.'}', (string) $value, $text);
        }

        return $text;
    }
}
