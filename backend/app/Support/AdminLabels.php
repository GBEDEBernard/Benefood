<?php

namespace App\Support;

use App\Enums\ComplaintStatus;
use App\Enums\DriverDocumentType;
use App\Enums\DriverStatus;
use App\Enums\OrderStatus;
use App\Enums\ParcelStatus;
use App\Enums\PaymentStatus;
use App\Enums\RefundStatus;
use App\Enums\UserStatus;
use App\Enums\VendorDocumentStatus;
use App\Enums\VendorDocumentType;
use App\Enums\VendorStatus;
use App\Enums\ZoneIdentificationMode;

/**
 * Libellés et badges de statut pour le back-office (cohérence UI Phase 06/07).
 */
class AdminLabels
{
    /** @return array{label: string, bg: string, fg: string} */
    public static function vendorStatus(string $status): array
    {
        return match ($status) {
            VendorStatus::Active->value => ['label' => 'Actif', 'bg' => '#EAF7EA', 'fg' => '#087B46'],
            VendorStatus::PendingVerification->value => ['label' => 'En attente de vérification', 'bg' => '#FFF2E2', 'fg' => '#E97800'],
            VendorStatus::Verified->value => ['label' => 'Vérifié', 'bg' => '#EDF3FE', 'fg' => '#2F6FED'],
            VendorStatus::Registered->value => ['label' => 'Enregistré', 'bg' => '#FFF2E2', 'fg' => '#E97800'],
            VendorStatus::Suspended->value => ['label' => 'Suspendu', 'bg' => '#FDECEC', 'fg' => '#D64545'],
            VendorStatus::Closed->value => ['label' => 'Fermé', 'bg' => '#F1F4F2', 'fg' => '#78817E'],
            default => ['label' => ucfirst($status), 'bg' => '#F1F4F2', 'fg' => '#78817E'],
        };
    }

    public static function vendorStatusBadge(string $status): string
    {
        $s = self::vendorStatus($status);

        return '<span class="badge badge-pill" style="background-color: '.$s['bg'].'; color: '.$s['fg'].'; font-weight: 600; padding: 6px 12px; border-radius: 20px;">'.$s['label'].'</span>';
    }

    /** @return array{label: string, bg: string, fg: string} */
    public static function userStatus(string $status): array
    {
        return match ($status) {
            UserStatus::Active->value => ['label' => 'Actif', 'bg' => '#EAF7EA', 'fg' => '#087B46'],
            UserStatus::Suspended->value => ['label' => 'Suspendu', 'bg' => '#FDECEC', 'fg' => '#D64545'],
            UserStatus::Closed->value => ['label' => 'Fermé', 'bg' => '#F1F4F2', 'fg' => '#78817E'],
            default => ['label' => ucfirst($status), 'bg' => '#F1F4F2', 'fg' => '#78817E'],
        };
    }

    public static function userStatusBadge(string $status): string
    {
        $s = self::userStatus($status);

        return '<span class="badge badge-pill" style="background-color: '.$s['bg'].'; color: '.$s['fg'].'; font-weight: 600; padding: 6px 12px; border-radius: 20px;">'.$s['label'].'</span>';
    }

    /** @return array{label: string, bg: string, fg: string} */
    public static function documentStatus(string $status): array
    {
        return match ($status) {
            VendorDocumentStatus::Valid->value => ['label' => 'Valide', 'bg' => '#EAF7EA', 'fg' => '#087B46'],
            VendorDocumentStatus::Submitted->value => ['label' => 'Soumis', 'bg' => '#FFF2E2', 'fg' => '#E97800'],
            VendorDocumentStatus::Invalid->value => ['label' => 'Rejeté', 'bg' => '#FDECEC', 'fg' => '#D64545'],
            default => ['label' => ucfirst($status), 'bg' => '#F1F4F2', 'fg' => '#78817E'],
        };
    }

    public static function documentStatusBadge(string $status): string
    {
        $s = self::documentStatus($status);

        return '<span class="badge badge-pill" style="background-color: '.$s['bg'].'; color: '.$s['fg'].'; font-weight: 600; padding: 6px 12px; border-radius: 20px;">'.$s['label'].'</span>';
    }

    public static function documentTypeLabel(string $type): string
    {
        return match ($type) {
            VendorDocumentType::IdCard->value => 'Pièce d’identité',
            VendorDocumentType::BusinessRegistration->value => 'Registre de commerce',
            VendorDocumentType::Ifu->value => 'IFU',
            VendorDocumentType::StorePhoto->value => 'Photo de boutique',
            default => ucfirst($type),
        };
    }

    /** @return array{label: string, bg: string, fg: string} */
    public static function orderStatus(string $status): array
    {
        return match ($status) {
            OrderStatus::Delivered->value => ['label' => 'Livrée', 'bg' => '#EAF7EA', 'fg' => '#087B46'],
            OrderStatus::Paid->value, OrderStatus::Accepted->value, OrderStatus::Preparing->value,
            OrderStatus::Ready->value, OrderStatus::Assigned->value, OrderStatus::PickedUp->value,
            OrderStatus::InDelivery->value => ['label' => 'En cours', 'bg' => '#EDF3FE', 'fg' => '#2F6FED'],
            OrderStatus::AwaitingPayment->value => ['label' => 'En attente de paiement', 'bg' => '#FFF2E2', 'fg' => '#E97800'],
            OrderStatus::Draft->value => ['label' => 'Brouillon', 'bg' => '#F1F4F2', 'fg' => '#78817E'],
            OrderStatus::Cancelled->value => ['label' => 'Annulée', 'bg' => '#FDECEC', 'fg' => '#D64545'],
            OrderStatus::Refunded->value => ['label' => 'Remboursée', 'bg' => '#F2ECFF', 'fg' => '#7D4CE0'],
            default => ['label' => ucfirst($status), 'bg' => '#F1F4F2', 'fg' => '#78817E'],
        };
    }

    public static function orderStatusBadge(string $status): string
    {
        $s = self::orderStatus($status);

        return '<span class="badge badge-pill" style="background-color: '.$s['bg'].'; color: '.$s['fg'].'; font-weight: 600; padding: 6px 12px; border-radius: 20px;">'.$s['label'].'</span>';
    }

    /** @return array{label: string, bg: string, fg: string} */
    public static function driverStatus(string $status): array
    {
        return match ($status) {
            DriverStatus::Active->value, DriverStatus::Validated->value => ['label' => 'Actif', 'bg' => '#EAF7EA', 'fg' => '#087B46'],
            DriverStatus::Candidate->value, DriverStatus::PendingValidation->value => ['label' => 'En validation', 'bg' => '#FFF2E2', 'fg' => '#E97800'],
            DriverStatus::Suspended->value => ['label' => 'Suspendu', 'bg' => '#FDECEC', 'fg' => '#D64545'],
            DriverStatus::Closed->value => ['label' => 'Fermé', 'bg' => '#F1F4F2', 'fg' => '#78817E'],
            default => ['label' => ucfirst($status), 'bg' => '#F1F4F2', 'fg' => '#78817E'],
        };
    }

    public static function driverStatusBadge(string $status): string
    {
        $s = self::driverStatus($status);

        return '<span class="badge badge-pill" style="background-color: '.$s['bg'].'; color: '.$s['fg'].'; font-weight: 600; padding: 6px 12px; border-radius: 20px;">'.$s['label'].'</span>';
    }

    /** @return array{label: string, bg: string, fg: string} */
    public static function refundStatus(string $status): array
    {
        return match ($status) {
            RefundStatus::Pending->value => ['label' => 'En attente', 'bg' => '#FFF2E2', 'fg' => '#E97800'],
            RefundStatus::Executed->value => ['label' => 'Exécuté', 'bg' => '#EAF7EA', 'fg' => '#087B46'],
            RefundStatus::Failed->value => ['label' => 'Échoué', 'bg' => '#FDECEC', 'fg' => '#D64545'],
            default => ['label' => ucfirst($status), 'bg' => '#F1F4F2', 'fg' => '#78817E'],
        };
    }

    public static function refundStatusBadge(string $status): string
    {
        $s = self::refundStatus($status);

        return '<span class="badge badge-pill" style="background-color: '.$s['bg'].'; color: '.$s['fg'].'; font-weight: 600; padding: 6px 12px; border-radius: 20px;">'.$s['label'].'</span>';
    }

    /** @return array{label: string, bg: string, fg: string} */
    public static function complaintStatus(string $status): array
    {
        return match ($status) {
            ComplaintStatus::Open->value => ['label' => 'Ouverte', 'bg' => '#FDECEC', 'fg' => '#D64545'],
            ComplaintStatus::InProgress->value => ['label' => 'En cours', 'bg' => '#FFF2E2', 'fg' => '#E97800'],
            ComplaintStatus::Closed->value => ['label' => 'Clôturée', 'bg' => '#EAF7EA', 'fg' => '#087B46'],
            default => ['label' => ucfirst($status), 'bg' => '#F1F4F2', 'fg' => '#78817E'],
        };
    }

    public static function complaintStatusBadge(string $status): string
    {
        $s = self::complaintStatus($status);

        return '<span class="badge badge-pill" style="background-color: '.$s['bg'].'; color: '.$s['fg'].'; font-weight: 600; padding: 6px 12px; border-radius: 20px;">'.$s['label'].'</span>';
    }

    /** @return array{label: string, bg: string, fg: string} */
    public static function paymentStatus(string $status): array
    {
        return match ($status) {
            PaymentStatus::Confirmed->value => ['label' => 'Payé', 'bg' => '#EAF7EA', 'fg' => '#087B46'],
            PaymentStatus::Initiated->value, PaymentStatus::Pending->value => ['label' => 'En attente', 'bg' => '#FFF2E2', 'fg' => '#E97800'],
            PaymentStatus::Refunded->value => ['label' => 'Remboursé', 'bg' => '#F2ECFF', 'fg' => '#7D4CE0'],
            PaymentStatus::Failed->value => ['label' => 'Échoué', 'bg' => '#FDECEC', 'fg' => '#D64545'],
            PaymentStatus::Expired->value, PaymentStatus::Cancelled->value => ['label' => 'Annulé', 'bg' => '#F1F4F2', 'fg' => '#78817E'],
            default => ['label' => ucfirst($status), 'bg' => '#F1F4F2', 'fg' => '#78817E'],
        };
    }

    public static function paymentStatusBadge(string $status): string
    {
        $s = self::paymentStatus($status);

        return '<span class="badge badge-pill" style="background-color: '.$s['bg'].'; color: '.$s['fg'].'; font-weight: 600; padding: 6px 12px; border-radius: 20px;">'.$s['label'].'</span>';
    }

    /** @return array{label: string, bg: string, fg: string} */
    public static function parcelStatus(string $status): array
    {
        return match ($status) {
            ParcelStatus::Delivered->value => ['label' => 'Livré', 'bg' => '#EAF7EA', 'fg' => '#087B46'],
            ParcelStatus::Paid->value => ['label' => 'Payé — à assigner', 'bg' => '#FFF2E2', 'fg' => '#E97800'],
            ParcelStatus::Assigned->value, ParcelStatus::EnRoutePickup->value, ParcelStatus::PickedUp->value, ParcelStatus::InDelivery->value => ['label' => 'En cours', 'bg' => '#EDF3FE', 'fg' => '#2F6FED'],
            ParcelStatus::AwaitingPayment->value => ['label' => 'En attente de paiement', 'bg' => '#FFF2E2', 'fg' => '#E97800'],
            ParcelStatus::Cancelled->value => ['label' => 'Annulé', 'bg' => '#FDECEC', 'fg' => '#D64545'],
            ParcelStatus::Refunded->value => ['label' => 'Remboursé', 'bg' => '#F2ECFF', 'fg' => '#7D4CE0'],
            default => ['label' => ucfirst($status), 'bg' => '#F1F4F2', 'fg' => '#78817E'],
        };
    }

    public static function parcelStatusBadge(string $status): string
    {
        $s = self::parcelStatus($status);

        return '<span class="badge badge-pill" style="background-color: '.$s['bg'].'; color: '.$s['fg'].'; font-weight: 600; padding: 6px 12px; border-radius: 20px;">'.$s['label'].'</span>';
    }

    public static function driverDocumentTypeLabel(string $type): string
    {
        return match ($type) {
            DriverDocumentType::IdCard->value => 'Pièce d’identité',
            DriverDocumentType::DriverLicense->value => 'Permis de conduire',
            DriverDocumentType::VehicleRegistration->value => 'Carte grise',
            DriverDocumentType::Insurance->value => 'Assurance',
            DriverDocumentType::Photo->value => 'Photo',
            default => ucfirst($type),
        };
    }

    public static function availableBadge(bool $available): string
    {
        return $available
            ? '<span class="badge badge-pill" style="background-color: #E0F7FA; color: #00838F; font-weight: 600; padding: 6px 12px; border-radius: 20px;">En ligne</span>'
            : '<span class="badge badge-pill" style="background-color: #F1F4F2; color: #78817E; font-weight: 600; padding: 6px 12px; border-radius: 20px;">Hors ligne</span>';
    }

    public static function dayLabel(int $day): string
    {
        $days = [
            0 => 'Dimanche',
            1 => 'Lundi',
            2 => 'Mardi',
            3 => 'Mercredi',
            4 => 'Jeudi',
            5 => 'Vendredi',
            6 => 'Samedi',
        ];

        return $days[$day] ?? '—';
    }

    /** @return array{label: string, bg: string, fg: string} */
    public static function productStatus(bool $isActive): array
    {
        return $isActive
            ? ['label' => 'Actif', 'bg' => '#EAF7EA', 'fg' => '#087B46']
            : ['label' => 'Inactif', 'bg' => '#F1F4F2', 'fg' => '#78817E'];
    }

    public static function productStatusBadge(bool $isActive): string
    {
        $s = self::productStatus($isActive);

        return '<span class="badge badge-pill" style="background-color: '.$s['bg'].'; color: '.$s['fg'].'; font-weight: 600; padding: 6px 12px; border-radius: 20px;">'.$s['label'].'</span>';
    }

    /** @return array{label: string, bg: string, fg: string} */
    public static function stockStatus(?int $stockQty, bool $isAvailable): array
    {
        if ($stockQty === null) {
            return ['label' => 'Illimité', 'bg' => '#EDF3FE', 'fg' => '#2F6FED'];
        }

        return $stockQty > 0 && $isAvailable
            ? ['label' => "En stock ({$stockQty})", 'bg' => '#EAF7EA', 'fg' => '#087B46']
            : ['label' => 'Épuisé', 'bg' => '#FDECEC', 'fg' => '#D64545'];
    }

    public static function stockBadge(?int $stockQty, bool $isAvailable): string
    {
        $s = self::stockStatus($stockQty, $isAvailable);

        return '<span class="badge badge-pill" style="background-color: '.$s['bg'].'; color: '.$s['fg'].'; font-weight: 600; padding: 6px 12px; border-radius: 20px;">'.$s['label'].'</span>';
    }

    /** @return array{label: string, bg: string, fg: string} */
    public static function categoryStatus(bool $isActive): array
    {
        return $isActive
            ? ['label' => 'Active', 'bg' => '#EAF7EA', 'fg' => '#087B46']
            : ['label' => 'Inactive', 'bg' => '#F1F4F2', 'fg' => '#78817E'];
    }

    public static function categoryStatusBadge(bool $isActive): string
    {
        $s = self::categoryStatus($isActive);

        return '<span class="badge badge-pill" style="background-color: '.$s['bg'].'; color: '.$s['fg'].'; font-weight: 600; padding: 6px 12px; border-radius: 20px;">'.$s['label'].'</span>';
    }

    /** @return array{label: string, bg: string, fg: string} */
    public static function zoneStatus(bool $isActive): array
    {
        return $isActive
            ? ['label' => 'Active', 'bg' => '#EAF7EA', 'fg' => '#087B46']
            : ['label' => 'Inactive', 'bg' => '#F1F4F2', 'fg' => '#78817E'];
    }

    public static function zoneStatusBadge(bool $isActive): string
    {
        $s = self::zoneStatus($isActive);

        return '<span class="badge badge-pill" style="background-color: '.$s['bg'].'; color: '.$s['fg'].'; font-weight: 600; padding: 6px 12px; border-radius: 20px;">'.$s['label'].'</span>';
    }

    public static function rateStatusBadge(bool $isActive): string
    {
        return $isActive
            ? '<span class="badge badge-pill" style="background-color: #EAF7EA; color: #087B46; font-weight: 600; padding: 6px 12px; border-radius: 20px;">Actif</span>'
            : '<span class="badge badge-pill" style="background-color: #F1F4F2; color: #78817E; font-weight: 600; padding: 6px 12px; border-radius: 20px;">Inactif</span>';
    }

    public static function zoneModeLabel(string $mode): string
    {
        return ZoneIdentificationMode::tryFrom($mode)?->label() ?? ucfirst($mode);
    }

    /**
     * Formate un prix produit en FCFA (montant entier — convention repère
     * existante côté back-office).
     */
    public static function priceLabel(int $price): string
    {
        return number_format($price, 0, ',', ' ').' F';
    }
}
