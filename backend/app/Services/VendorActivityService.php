<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Enums\VendorDocumentStatus;
use App\Enums\VendorDocumentType;
use App\Enums\VendorStatus;
use App\Models\OrderStatusHistory;
use App\Models\Vendor;
use Illuminate\Support\Collection;

/**
 * Historique des activités vendeur (J21 §10) : reconstitue une chronologie
 * lisible à partir des traces existantes (cycle de vie du compte, documents,
 * commandes et produits) sans dupliquer les données.
 */
class VendorActivityService
{
    /**
     * @return array<int, array<string, mixed>>
     */
    public function forVendor(Vendor $vendor, int $limit = 100): array
    {
        $events = collect()
            ->concat($this->accountEvents($vendor))
            ->concat($this->documentEvents($vendor))
            ->concat($this->orderEvents($vendor))
            ->concat($this->productEvents($vendor));

        return $events
            ->sortByDesc('created_at')
            ->take($limit)
            ->values()
            ->all();
    }

    /**
     * @return Collection<int, array<string, mixed>>
     */
    private function accountEvents(Vendor $vendor): Collection
    {
        $labels = [
            VendorStatus::Registered->value => 'Inscription créée',
            VendorStatus::PendingVerification->value => 'Dossier en cours de vérification',
            VendorStatus::Verified->value => 'Dossier validé',
            VendorStatus::Active->value => 'Compte activé',
            VendorStatus::Suspended->value => 'Compte suspendu',
            VendorStatus::Closed->value => 'Compte fermé',
        ];

        return $vendor->statusHistory()
            ->get()
            ->map(fn ($history) => $this->event(
                type: 'account',
                action: 'status_'.$history->to_status,
                label: $labels[$history->to_status] ?? 'Statut du compte mis à jour',
                description: $history->reason,
                status: $history->to_status,
                at: $history->created_at,
            ));
    }

    /**
     * @return Collection<int, array<string, mixed>>
     */
    private function documentEvents(Vendor $vendor): Collection
    {
        $events = collect();

        foreach ($vendor->documents()->get() as $document) {
            $typeLabel = $this->documentTypeLabel($document->type);

            $events->push($this->event(
                type: 'document',
                action: 'document_submitted',
                label: 'Document soumis',
                description: $typeLabel,
                status: VendorDocumentStatus::Submitted->value,
                at: $document->created_at,
            ));

            if ($document->reviewed_at === null) {
                continue;
            }

            $accepted = $document->status === VendorDocumentStatus::Valid->value;

            $events->push($this->event(
                type: 'document',
                action: $accepted ? 'document_accepted' : 'document_rejected',
                label: $accepted ? 'Document accepté' : 'Document rejeté',
                description: trim($typeLabel.($document->reason ? ' · '.$document->reason : '')),
                status: $document->status,
                at: $document->reviewed_at,
            ));
        }

        return $events;
    }

    /**
     * @return Collection<int, array<string, mixed>>
     */
    private function orderEvents(Vendor $vendor): Collection
    {
        $labels = [
            OrderStatus::Paid->value => 'Commande payée',
            OrderStatus::Accepted->value => 'Commande acceptée',
            OrderStatus::Preparing->value => 'Préparation démarrée',
            OrderStatus::Ready->value => 'Commande prête',
            OrderStatus::Assigned->value => 'Livreur assigné',
            OrderStatus::PickedUp->value => 'Commande récupérée',
            OrderStatus::InDelivery->value => 'Commande en livraison',
            OrderStatus::Delivered->value => 'Commande livrée',
            OrderStatus::Cancelled->value => 'Commande annulée',
            OrderStatus::Refunded->value => 'Commande remboursée',
        ];

        $orderIds = $vendor->orders()->pluck('id');

        if ($orderIds->isEmpty()) {
            return collect();
        }

        return OrderStatusHistory::query()
            ->whereIn('order_id', $orderIds)
            ->with('order:id,reference')
            ->get()
            ->map(fn (OrderStatusHistory $history) => $this->event(
                type: 'order',
                action: 'order_'.$history->to_status,
                label: $labels[$history->to_status] ?? 'Commande mise à jour',
                description: trim(($history->order?->reference ?? '').($history->reason ? ' · '.$history->reason : ''), ' ·'),
                status: $history->to_status,
                at: $history->created_at,
            ));
    }

    /**
     * @return Collection<int, array<string, mixed>>
     */
    private function productEvents(Vendor $vendor): Collection
    {
        return $vendor->products()
            ->get()
            ->flatMap(function ($product) {
                $events = collect();

                $events->push($this->event(
                    type: 'product',
                    action: 'product_created',
                    label: 'Produit ajouté',
                    description: $product->name,
                    status: $product->is_active ? 'active' : 'inactive',
                    at: $product->created_at,
                ));

                if ($product->updated_at !== null && $product->created_at !== null && $product->updated_at->greaterThan($product->created_at->copy()->addSecond())) {
                    $events->push($this->event(
                        type: 'product',
                        action: 'product_updated',
                        label: $product->is_active ? 'Produit modifié' : 'Produit désactivé',
                        description: $product->name,
                        status: $product->is_active ? 'active' : 'inactive',
                        at: $product->updated_at,
                    ));
                }

                return $events;
            });
    }

    /**
     * @return array<string, mixed>
     */
    private function event(
        string $type,
        string $action,
        string $label,
        ?string $description,
        ?string $status,
        ?\DateTimeInterface $at,
    ): array {
        return [
            'id' => $type.'-'.$action.'-'.($at?->getTimestamp() ?? 0).'-'.md5(($description ?? '').($at?->format('YmdHis') ?? '')),
            'type' => $type,
            'action' => $action,
            'label' => $label,
            'description' => $description,
            'status' => $status,
            'created_at' => $at?->format(\DateTimeInterface::ATOM),
        ];
    }

    private function documentTypeLabel(string $type): string
    {
        return match ($type) {
            VendorDocumentType::IdCard->value => 'Pièce d\'identité',
            VendorDocumentType::BusinessRegistration->value => 'Registre de commerce / Patente',
            VendorDocumentType::Ifu->value => 'IFU (Identifiant Fiscal Unique)',
            VendorDocumentType::StorePhoto->value => 'Photo de la boutique',
            default => $type,
        };
    }
}
