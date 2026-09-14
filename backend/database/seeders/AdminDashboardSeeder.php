<?php

namespace Database\Seeders;

use App\Models\DeliveryZone;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Filesystem\Filesystem;
use Illuminate\Support\Str;

class AdminDashboardSeeder extends Seeder
{
    public function run(): void
    {
        // copy admin template assets if present at repository root
        $fs = new Filesystem();
        $src = base_path('../Mentor-Bootstrap4-Admin-Dashboard-Template');
        $dest = public_path('admin-assets');

        if ($fs->isDirectory($src)) {
            $fs->ensureDirectoryExists($dest);
            $fs->copyDirectory($src, $dest);
        }

        // create admin user
        $admin = User::firstOrCreate([
            'email' => 'admin@local'
        ], [
            'name' => 'Admin',
            'phone' => '00000000',
            'password' => bcrypt('password'),
        ]);

        // attach admin role if exists
        if (class_exists(Role::class)) {
            $role = Role::where('slug', 'admin-technique')->first();
            if ($role) {
                $admin->roles()->syncWithoutDetaching([$role->id => ['is_active' => true]]);
            }
        }

        // seed some zones if none
        if (DeliveryZone::count() === 0) {
            DeliveryZone::create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
            DeliveryZone::create(['name' => 'Porto-Novo', 'city' => 'Porto-Novo']);
        }
    }
}
