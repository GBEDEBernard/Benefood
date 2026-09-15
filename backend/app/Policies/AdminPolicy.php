<?php

namespace App\Policies;

use App\Models\User;

/**
 * Accès back-office (J32 §4 — AdminPolicy).
 */
class AdminPolicy
{
    public function manage(User $user): bool
    {
        // Allow platform administrators and technical admins to manage the back-office.
        $allowed = ['porteuse', 'admin-technique', 'admin', 'super-admin'];

        foreach ($allowed as $role) {
            if ($user->hasRole($role)) {
                return true;
            }
        }

        return false;
    }
}
