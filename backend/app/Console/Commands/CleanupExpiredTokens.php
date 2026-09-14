<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class CleanupExpiredTokens extends Command
{
    protected $signature = 'tokens:cleanup';

    protected $description = 'Purger les jetons Sanctum expirés.';

    public function handle(): int
    {
        $deleted = DB::table('personal_access_tokens')
            ->whereNotNull('expires_at')
            ->where('expires_at', '<', now())
            ->delete();

        $this->info("{$deleted} jeton(s) périmé(s) supprimé(s).");

        return self::SUCCESS;
    }
}
