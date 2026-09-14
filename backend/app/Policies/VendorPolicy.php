<?php

namespace App\Policies;

use App\Models\User;
use App\Models\Vendor;

/**
 * Accès aux ressources vendeur (J32 §4).
 */
class VendorPolicy
{
    public function create(User $user): bool
    {
        return true;
    }

    public function view(User $user, Vendor $vendor): bool
    {
        return $user->id === $vendor->user_id
            || $user->hasRole('porteuse')
            || $user->hasRole('admin-technique');
    }

    public function update(User $user, Vendor $vendor): bool
    {
        return $user->id === $vendor->user_id && $user->hasPermission('vendor.profile.manage');
    }

    public function manageDocuments(User $user, Vendor $vendor): bool
    {
        return $user->id === $vendor->user_id && $user->hasPermission('vendor.documents.manage');
    }

    public function approve(User $user): bool
    {
        return $user->hasPermission('admin.vendors.approve');
    }

    public function suspend(User $user): bool
    {
        return $user->hasPermission('admin.vendors.suspend');
    }
}
