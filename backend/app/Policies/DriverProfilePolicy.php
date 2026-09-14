<?php

namespace App\Policies;

use App\Models\DriverProfile;
use App\Models\User;

/**
 * Accès aux ressources livreur (J32 §4).
 */
class DriverProfilePolicy
{
    public function create(User $user): bool
    {
        return true;
    }

    public function view(User $user, DriverProfile $profile): bool
    {
        return $user->id === $profile->user_id
            || $user->hasRole('porteuse')
            || $user->hasRole('admin-technique');
    }

    public function update(User $user, DriverProfile $profile): bool
    {
        return $user->id === $profile->user_id && $user->hasPermission('driver.documents.manage');
    }

    public function manageDocuments(User $user, DriverProfile $profile): bool
    {
        return $user->id === $profile->user_id && $user->hasPermission('driver.documents.manage');
    }

    public function toggleAvailability(User $user, DriverProfile $profile): bool
    {
        return $user->id === $profile->user_id
            && $user->hasPermission('driver.availability.manage')
            && $profile->status === 'active';
    }
}
