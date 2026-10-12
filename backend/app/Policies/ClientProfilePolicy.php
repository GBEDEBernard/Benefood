<?php

namespace App\Policies;

use App\Models\ClientProfile;
use App\Models\User;

/**
 * Accès au dossier client (J19).
 */
class ClientProfilePolicy
{
    public function create(User $user): bool
    {
        return true;
    }

    public function view(User $user, ClientProfile $profile): bool
    {
        return $user->id === $profile->user_id
            || $user->hasRole('porteuse')
            || $user->hasRole('admin-technique');
    }

    public function update(User $user, ClientProfile $profile): bool
    {
        return $user->id === $profile->user_id;
    }

    public function manageDocuments(User $user, ClientProfile $profile): bool
    {
        return $user->id === $profile->user_id;
    }
}
