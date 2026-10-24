<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LoginPageTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    public function test_login_page_renders_the_premium_admin_shell(): void
    {
        $this->get(route('login'))
            ->assertOk()
            ->assertViewIs('auth.login')
            ->assertSee('Connexion administrateur')
            ->assertSee('Accédez à votre tableau de bord Béninfood.')
            ->assertSee('assets/img/logo-beninfood.jpeg', false)
            ->assertSee('assets/css/login.css', false)
            ->assertSee('assets/js/login.js', false)
            ->assertSee('name="_token"', false)
            ->assertSee('name="email"', false)
            ->assertSee('name="password"', false)
            ->assertSee('data-password-toggle', false)
            ->assertSee('autocomplete="username"', false)
            ->assertSee('autocomplete="current-password"', false)
            ->assertSee('Réinitialisation via l’administrateur', false)
            ->assertDontSee('Mot de passe oublié');
    }

    public function test_admin_can_login_and_is_redirected_to_the_dashboard(): void
    {
        $admin = $this->admin();

        $this->post(route('login.post'), [
            'email' => $admin->email,
            'password' => 'password',
        ])->assertRedirect(route('admin.dashboard'));

        $this->assertAuthenticatedAs($admin);
    }

    public function test_invalid_credentials_return_a_french_error_and_keep_the_email(): void
    {
        $user = User::factory()->create(['email' => 'admin@example.test']);

        $this->from(route('login'))
            ->followingRedirects()
            ->post(route('login.post'), [
                'email' => $user->email,
                'password' => 'mauvais-mot-de-passe',
            ])
            ->assertOk()
            ->assertSee('Les identifiants sont invalides.')
            ->assertSee('value="'.$user->email.'"', false);
    }

    public function test_login_validates_empty_and_invalid_fields_in_french(): void
    {
        $this->from(route('login'))
            ->post(route('login.post'), [])
            ->assertRedirect(route('login'))
            ->assertSessionHasErrors([
                'email' => 'Veuillez saisir votre adresse e-mail.',
                'password' => 'Veuillez saisir votre mot de passe.',
            ]);

        $this->from(route('login'))
            ->post(route('login.post'), [
                'email' => 'pas-un-email',
                'password' => 'secret',
            ])
            ->assertRedirect(route('login'))
            ->assertSessionHasErrors([
                'email' => 'Veuillez saisir une adresse e-mail valide.',
            ]);
    }

    public function test_authenticated_non_admin_still_cannot_reach_the_back_office(): void
    {
        $client = $this->client();

        $this->post(route('login.post'), [
            'email' => $client->email,
            'password' => 'password',
        ])->assertRedirect(route('admin.dashboard'));

        $this->get(route('admin.dashboard'))->assertForbidden();
    }

    public function test_logout_invalidates_the_session_and_returns_to_login(): void
    {
        $admin = $this->admin();

        $this->actingAs($admin)
            ->post(route('logout'))
            ->assertRedirect(route('login'));

        $this->assertGuest();
    }

    private function admin(): User
    {
        $admin = User::factory()->create(['email' => 'admin@local']);
        $admin->roles()->attach(Role::where('slug', 'admin-technique')->firstOrFail(), ['is_active' => true]);

        return $admin;
    }

    private function client(): User
    {
        $client = User::factory()->create(['email' => 'client@example.test']);
        $client->roles()->attach(Role::where('slug', 'client')->firstOrFail(), ['is_active' => true]);

        return $client;
    }
}
