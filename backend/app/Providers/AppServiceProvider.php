<?php

namespace App\Providers;

use App\Models\DriverProfile;
use App\Models\User;
use App\Models\Vendor;
use App\Policies\AdminPolicy;
use App\Policies\DriverProfilePolicy;
use App\Policies\VendorPolicy;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->configurePolicies();
        $this->configureRateLimiting();
    }

    private function configurePolicies(): void
    {
        Gate::policy(Vendor::class, VendorPolicy::class);
        Gate::policy(DriverProfile::class, DriverProfilePolicy::class);
        Gate::policy(User::class, AdminPolicy::class);
    }

    private function configureRateLimiting(): void
    {
        RateLimiter::for('api', function (Request $request): Limit {
            return Limit::perMinute(60)->by($request->user()?->id ?: $request->ip());
        });

        RateLimiter::for('auth', function (Request $request): Limit {
            return Limit::perMinute(5)->by($request->ip());
        });
    }
}
