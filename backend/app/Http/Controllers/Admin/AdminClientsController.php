<?php

namespace App\Http\Controllers\Admin;

use App\Enums\UserStatus;
use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AdminClientsController extends Controller
{
    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $query = User::query()
            ->with(['roles', 'vendor', 'driverProfile'])
            ->withCount(['roles', 'devices'])
            ->whereHas('roles', fn ($q) => $q->where('slug', 'client'));

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($search = trim((string) $request->query('q'))) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%");
            });
        }

        $users = $query->orderByDesc('created_at')->paginate(20)->withQueryString();

        return view('admin.clients.index', [
            'users' => $users,
            'roles' => Role::orderBy('name')->get(),
            'statuses' => UserStatus::cases(),
            'filters' => [
                'q' => $request->query('q'),
                'status' => $status,
            ],
        ]);
    }

    public function show(User $client): View
    {
        $this->authorize('manage', User::class);

        $client->load(['roles', 'devices', 'vendor', 'driverProfile']);

        return view('admin.clients.show', [
            'user' => $client,
            'roles' => Role::orderBy('name')->get(),
        ]);
    }

    public function edit(User $client): View
    {
        return $this->show($client);
    }

    public function update(Request $request, User $client): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255'],
        ]);

        $client->update($data);

        return back()->with('success', 'Client mis à jour.');
    }

    public function destroy(User $client): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $client->update(['status' => UserStatus::Closed->value]);

        return redirect()->route('admin.clients.index')->with('success', 'Client supprimé (statut fermé).');
    }
}
