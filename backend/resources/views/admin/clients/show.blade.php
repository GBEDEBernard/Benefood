@extends('layouts.app')

@section('content')
<x-admin.page-header title="Client" :subtitle="$user->phone" :back="route('admin.clients.index')">
    {!! \App\Support\AdminLabels::userStatusBadge($user->status) !!}
</x-admin.page-header>

@if (session('success'))
    <div class="alert alert-success alert-dismissible fade show" role="alert">
        {{ session('success') }}
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif

<div class="row">
    <div class="col-lg-4">
        <div class="card mb-4">
            <div class="card-body text-center">
                <div class="mx-auto rounded-circle d-flex align-items-center justify-content-center mb-3" style="width: 80px; height: 80px; background-color: #E8F5E9; font-weight: 700; color: var(--benin-green); font-size: 30px;">
                    {{ strtoupper(substr($user->name, 0, 1)) }}
                </div>
                <h5 class="mb-1" style="color: var(--text-dark); font-weight: 700;">{{ $user->name }}</h5>
                <p class="mb-2" style="color: var(--text-muted);">{{ $user->email ?? '—' }}</p>
                <div class="mb-3">
                    @forelse ($user->roles as $role)
                        <span class="badge mr-1" style="background-color: {{ $role->pivot->is_active ? '#E8F5E9' : '#F1F3F4' }}; color: {{ $role->pivot->is_active ? 'var(--benin-green)' : 'var(--text-muted)' }};">@if ($role->pivot->is_active) <i class="ti ti-check"></i> @endif {{ $role->name }}</span>
                    @empty
                        <span class="text-muted">Aucun rôle</span>
                    @endforelse
                </div>
                <hr>
                <div class="text-left">
                    <p class="mb-2" style="color: var(--text-muted);"><i class="ti ti-mobile mr-2"></i>{{ $user->phone }}</p>
                    <p class="mb-2" style="color: var(--text-muted);"><i class="ti ti-world mr-2"></i>Locale : {{ strtoupper($user->locale) }}</p>
                    <p class="mb-2" style="color: var(--text-muted);">Téléphone vérifié : <strong style="color: {{ $user->phone_verified_at ? 'var(--benin-green)' : 'var(--benin-red)' }};">{{ $user->phone_verified_at ? 'Oui' : 'Non' }}</strong></p>
                    @if ($user->email_verified_at)
                        <p class="mb-2" style="color: var(--text-muted);"><i class="ti ti-email mr-2"></i>Email vérifié</p>
                    @endif
                    <p class="mb-0" style="color: var(--text-muted);">Inscrit le {{ $user->created_at?->format('d/m/Y H:i') }}</p>
                </div>
            </div>
        </div>
    </div>

    <div class="col-lg-8">
        <div class="card mb-4">
            <div class="card-header">
                <h5 class="mb-0">Statut du compte</h5>
            </div>
            <div class="card-body">
                <form method="POST" action="{{ route('admin.users.status', $user) }}" class="row align-items-end">
                    @csrf
                    <div class="col-md-6">
                        <label>Changer le statut</label>
                        <select name="status" class="form-control">
                            @foreach (\App\Enums\UserStatus::cases() as $status)
                                <option value="{{ $status->value }}" @selected($user->status === $status->value)>{{ ucfirst($status->value) }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="col-md-6">
                        <button type="submit" class="btn btn-block" style="background-color: var(--benin-green); color: #FFFFFF;">Enregistrer</button>
                    </div>
                </form>
            </div>
        </div>

        <div class="card mb-4">
            <div class="card-header d-flex justify-content-between align-items-center">
                <h5 class="mb-0">Rôles et permissions</h5>
                <small class="text-muted">Le premier rôle coché devient le rôle actif</small>
            </div>
            <div class="card-body">
                <form method="POST" action="{{ route('admin.users.roles', $user) }}">
                    @csrf
                    <div class="row">
                        @foreach ($roles as $role)
                            <div class="col-md-6">
                                <div class="custom-control custom-checkbox mb-3" style="border: 1px solid var(--border-color); padding: 12px; border-radius: 10px;">
                                    <input type="checkbox" class="custom-control-input" id="role-{{ $role->id }}" name="roles[]" value="{{ $role->id }}" @checked($user->roles->contains('id', $role->id))>
                                    <label class="custom-control-label" for="role-{{ $role->id }}" style="cursor: pointer;"> <strong>{{ $role->name }}</strong><br><small class="text-muted">{{ $role->description }}</small></label>
                                </div>
                            </div>
                        @endforeach
                    </div>
                    <button type="submit" class="btn" style="background-color: var(--benin-green); color: #FFFFFF;">Mettre à jour les rôles</button>
                </form>
            </div>
        </div>

        <div class="card mb-4">
            <div class="card-header"><h5 class="mb-0">Appareils connectés</h5></div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table mb-0">
                        <thead style="background-color: #F9FAFB;"><tr><th>Plateforme</th><th>Version</th><th>Dernière activité</th></tr></thead>
                        <tbody>
                            @forelse ($user->devices as $device)
                                <tr><td>{{ $device->platform }} <small class="text-muted">({{ $device->device_type ?? '—' }})</small></td><td>{{ $device->app_version ?? '—' }}</td><td>{{ $device->last_seen_at?->diffForHumans() ?? '—' }}</td></tr>
                            @empty
                                <tr><td colspan="3" class="text-center py-4 text-muted">Aucun appareil enregistré.</td></tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>
@endsection
