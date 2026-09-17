<?php

namespace App\Services;

use App\Enums\ComplaintStatus;
use App\Exceptions\DomainException;
use App\Models\Complaint;
use App\Models\ComplaintMessage;
use App\Models\Order;
use App\Models\User;

/**
 * Réclamations / litiges (M12 — J122).
 *
 * Le client ouvre la réclamation (optionnellement liée à une commande), la
 * porteuse la prend en charge (in_progress), répond et clôture. Chaque message
 * est tracé avec son auteur (user / porteuse).
 */
class ComplaintService
{
    public function __construct(private readonly NotificationService $notifications) {}

    /**
     * Ouvre une nouvelle réclamation pour un client, optionnellement liée à une commande.
     *
     * @param  array{order_id?: string|null, type: string, subject: string, description: string}  $data
     */
    public function open(User $user, array $data): Complaint
    {
        $orderId = $data['order_id'] ?? null;

        if ($orderId !== null && Order::where('id', $orderId)->where('user_id', $user->id)->doesntExist()) {
            throw new DomainException('complaint.order_forbidden', 'La commande référencée ne vous appartient pas.', 422);
        }

        $complaint = Complaint::create([
            'user_id' => $user->id,
            'order_id' => $orderId,
            'type' => $data['type'],
            'subject' => $data['subject'],
            'description' => $data['description'],
            'status' => ComplaintStatus::Open->value,
        ]);

        $this->notifications->notifyEvent('complaint.opened', $this->notifications->porteuseUsers()->all(), [
            'complaint_id' => $complaint->id,
            'subject' => $complaint->subject,
        ]);

        return $complaint->fresh('messages');
    }

    /**
     * Ajoute un message à une réclamation ouverte (client ou porteuse).
     */
    public function reply(Complaint $complaint, User $sender, string $message): ComplaintMessage
    {
        if ($complaint->status === ComplaintStatus::Closed) {
            throw new DomainException('complaint.closed', 'Cette réclamation est clôturée.', 409);
        }

        $this->assertParticipant($complaint, $sender);

        $isSupport = $this->isSupport($sender);

        $sent = $complaint->messages()->create([
            'sender_type' => $isSupport ? 'porteuse' : 'user',
            'message' => $message,
        ]);

        $recipients = $isSupport
            ? [$complaint->user]
            : $this->notifications->porteuseUsers()->all();

        $this->notifications->notifyEvent('complaint.message', $recipients, [
            'complaint_id' => $complaint->id,
            'subject' => $complaint->subject,
        ]);

        return $sent;
    }

    /**
     * Marque une réclamation en cours de traitement (porteuse).
     */
    public function markInProgress(Complaint $complaint, User $actor): Complaint
    {
        $this->assertSupport($actor);

        if ($complaint->status === ComplaintStatus::Closed) {
            throw new DomainException('complaint.closed', 'Cette réclamation est déjà clôturée.', 409);
        }

        $complaint->update(['status' => ComplaintStatus::InProgress->value]);

        return $complaint->fresh('messages');
    }

    /**
     * Clôture une réclamation (porteuse) et notifie le client.
     */
    public function close(Complaint $complaint, User $actor, ?string $resolution = null): Complaint
    {
        $this->assertSupport($actor);

        $complaint->update([
            'status' => ComplaintStatus::Closed->value,
            'resolution' => $resolution,
            'closed_by' => $actor->id,
            'closed_at' => now(),
        ]);

        $this->notifications->notifyEvent('complaint.resolved', [$complaint->user], [
            'complaint_id' => $complaint->id,
            'subject' => $complaint->subject,
        ]);

        return $complaint->fresh('messages');
    }

    /**
     * L'auteur du message doit être le propriétaire de la réclamation ou un agent support.
     */
    private function assertParticipant(Complaint $complaint, User $user): void
    {
        if ($complaint->user_id !== $user->id && ! $this->isSupport($user)) {
            throw new DomainException('complaint.forbidden', 'Vous ne pouvez pas intervenir sur cette réclamation.', 403);
        }
    }

    private function isSupport(User $user): bool
    {
        return $user->hasPermission('admin.support.resolve');
    }

    private function assertSupport(User $user): void
    {
        if (! $this->isSupport($user)) {
            throw new DomainException('complaint.forbidden', 'Accès réservé au support.', 403);
        }
    }
}
