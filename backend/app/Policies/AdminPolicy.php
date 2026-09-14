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
        return $user->hasRole('porteuse') || $user->hasRole('admin-technique');
    }
}
