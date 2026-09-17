<?php

namespace App\Support;

use App\Enums\ComplaintStatus;
use App\Enums\DriverDocumentType;
use App\Enums\DriverStatus;
use App\Enums\OrderStatus;
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
            VendorStatus::Active->value => ['label' => 'Actif', 'bg' => '#E8F5E9', 'fg' => '#2E7D32'],
            VendorStatus::PendingVerification->value => ['label' => 'En attente de vérification', 'bg' => '#FFF3E0', 'fg' => '#E65100'],
            VendorStatus::Verified->value => ['label' => 'Vérifié', 'bg' => '#E1F5FE', 'fg' => '#0277BD'],
            VendorStatus::Registered->value => ['label' => 'Enregistré', 'bg' => '#FFF3E0', 'fg' => '#E65100'],
            VendorStatus::Suspended->value => ['label' => 'Suspendu', 'bg' => '#FFEBEE', 'fg' => '#C62828'],
            VendorStatus::Closed->value => ['label' => 'Fermé', 'bg' => '#ECEFF1', 'fg' => '#37474F'],
            default => ['label' => ucfirst($status), 'bg' => '#ECEFF1', 'fg' => '#37474F'],
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
            UserStatus::Active->value => ['label' => 'Actif', 'bg' => '#E8F5E9', 'fg' => '#2E7D32'],
            UserStatus::Suspended->value => ['label' => 'Suspendu', 'bg' => '#FFEBEE', 'fg' => '#C62828'],
            UserStatus::Closed->value => ['label' => 'Fermé', 'bg' => '#ECEFF1', 'fg' => '#37474F'],
            default => ['label' => ucfirst($status), 'bg' => '#ECEFF1', 'fg' => '#37474F'],
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
            VendorDocumentStatus::Valid->value => ['label' => 'Valide', 'bg' => '#E8F5E9', 'fg' => '#2E7D32'],
            VendorDocumentStatus::Submitted->value => ['label' => 'Soumis', 'bg' => '#FFF3E0', 'fg' => '#E65100'],
            VendorDocumentStatus::Invalid->value => ['label' => 'Rejeté', 'bg' => '#FFEBEE', 'fg' => '#C62828'],
            default => ['label' => ucfirst($status), 'bg' => '#ECEFF1', 'fg' => '#37474F'],
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
            OrderStatus::Delivered->value => ['label' => 'Livrée', 'bg' => '#E8F5E9', 'fg' => '#2E7D32'],
            OrderStatus::Paid->value, OrderStatus::Accepted->value, OrderStatus::Preparing->value,
            OrderStatus::Ready->value, OrderStatus::Assigned->value, OrderStatus::PickedUp->value,
            OrderStatus::InDelivery->value => ['label' => 'En cours', 'bg' => '#E1F5FE', 'fg' => '#0277BD'],
            OrderStatus::AwaitingPayment->value => ['label' => 'En attente de paiement', 'bg' => '#FFF3E0', 'fg' => '#E65100'],
            OrderStatus::Draft->value => ['label' => 'Brouillon', 'bg' => '#ECEFF1', 'fg' => '#37474F'],
            OrderStatus::Cancelled->value => ['label' => 'Annulée', 'bg' => '#FFEBEE', 'fg' => '#C62828'],
            OrderStatus::Refunded->value => ['label' => 'Remboursée', 'bg' => '#F3E5F5', 'fg' => '#6A1B9A'],
            default => ['label' => ucfirst($status), 'bg' => '#ECEFF1', 'fg' => '#37474F'],
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
            DriverStatus::Active->value, DriverStatus::Validated->value => ['label' => 'Actif', 'bg' => '#E8F5E9', 'fg' => '#2E7D32'],
            DriverStatus::Candidate->value, DriverStatus::PendingValidation->value => ['label' => 'En validation', 'bg' => '#FFF3E0', 'fg' => '#E65100'],
            DriverStatus::Suspended->value => ['label' => 'Suspendu', 'bg' => '#FFEBEE', 'fg' => '#C62828'],
            DriverStatus::Closed->value => ['label' => 'Fermé', 'bg' => '#ECEFF1', 'fg' => '#37474F'],
            default => ['label' => ucfirst($status), 'bg' => '#ECEFF1', 'fg' => '#37474F'],
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
            RefundStatus::Pending->value => ['label' => 'En attente', 'bg' => '#FFF3E0', 'fg' => '#E65100'],
            RefundStatus::Executed->value => ['label' => 'Exécuté', 'bg' => '#E8F5E9', 'fg' => '#2E7D32'],
            RefundStatus::Failed->value => ['label' => 'Échoué', 'bg' => '#FFEBEE', 'fg' => '#C62828'],
            default => ['label' => ucfirst($status), 'bg' => '#ECEFF1', 'fg' => '#37474F'],
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
            ComplaintStatus::Open->value => ['label' => 'Ouverte', 'bg' => '#FFEBEE', 'fg' => '#C62828'],
            ComplaintStatus::InProgress->value => ['label' => 'En cours', 'bg' => '#FFF3E0', 'fg' => '#E65100'],
            ComplaintStatus::Closed->value => ['label' => 'Clôturée', 'bg' => '#E8F5E9', 'fg' => '#2E7D32'],
            default => ['label' => ucfirst($status), 'bg' => '#ECEFF1', 'fg' => '#37474F'],
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
            PaymentStatus::Confirmed->value => ['label' => 'Payé', 'bg' => '#E8F5E9', 'fg' => '#2E7D32'],
            PaymentStatus::Initiated->value, PaymentStatus::Pending->value => ['label' => 'En attente', 'bg' => '#FFF3E0', 'fg' => '#E65100'],
            PaymentStatus::Refunded->value => ['label' => 'Remboursé', 'bg' => '#F3E5F5', 'fg' => '#6A1B9A'],
            PaymentStatus::Failed->value => ['label' => 'Échoué', 'bg' => '#FFEBEE', 'fg' => '#C62828'],
            PaymentStatus::Expired->value, PaymentStatus::Cancelled->value => ['label' => 'Annulé', 'bg' => '#ECEFF1', 'fg' => '#37474F'],
            default => ['label' => ucfirst($status), 'bg' => '#ECEFF1', 'fg' => '#37474F'],
        };
    }

    public static function paymentStatusBadge(string $status): string
    {
        $s = self::paymentStatus($status);

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
            : '<span class="badge badge-pill" style="background-color: #ECEFF1; color: #37474F; font-weight: 600; padding: 6px 12px; border-radius: 20px;">Hors ligne</span>';
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
            ? ['label' => 'Actif', 'bg' => '#E8F5E9', 'fg' => '#2E7D32']
            : ['label' => 'Inactif', 'bg' => '#ECEFF1', 'fg' => '#37474F'];
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
            return ['label' => 'Illimité', 'bg' => '#E1F5FE', 'fg' => '#0277BD'];
        }

        return $stockQty > 0 && $isAvailable
            ? ['label' => "En stock ({$stockQty})", 'bg' => '#E8F5E9', 'fg' => '#2E7D32']
            : ['label' => 'Épuisé', 'bg' => '#FFEBEE', 'fg' => '#C62828'];
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
            ? ['label' => 'Active', 'bg' => '#E8F5E9', 'fg' => '#2E7D32']
            : ['label' => 'Inactive', 'bg' => '#ECEFF1', 'fg' => '#37474F'];
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
            ? ['label' => 'Active', 'bg' => '#E8F5E9', 'fg' => '#2E7D32']
            : ['label' => 'Inactive', 'bg' => '#ECEFF1', 'fg' => '#37474F'];
    }

    public static function zoneStatusBadge(bool $isActive): string
    {
        $s = self::zoneStatus($isActive);

        return '<span class="badge badge-pill" style="background-color: '.$s['bg'].'; color: '.$s['fg'].'; font-weight: 600; padding: 6px 12px; border-radius: 20px;">'.$s['label'].'</span>';
    }

    public static function rateStatusBadge(bool $isActive): string
    {
        return $isActive
            ? '<span class="badge badge-pill" style="background-color: #E8F5E9; color: #2E7D32; font-weight: 600; padding: 6px 12px; border-radius: 20px;">Actif</span>'
            : '<span class="badge badge-pill" style="background-color: #ECEFF1; color: #37474F; font-weight: 600; padding: 6px 12px; border-radius: 20px;">Inactif</span>';
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
