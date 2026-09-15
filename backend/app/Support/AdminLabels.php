<?php

namespace App\Support;

use App\Enums\UserStatus;
use App\Enums\VendorDocumentStatus;
use App\Enums\VendorDocumentType;
use App\Enums\VendorStatus;

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
}