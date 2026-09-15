@extends('layouts.app')

@section('content')
<x-admin.page-header title="Utilisateur" :subtitle="$user->phone" :back="route('admin.users.index')">
    {!! \App\Support\AdminLabels::userStatusBadge($user->status) !!}
</x-admin.page-header>

@if (session('success'))
    <div class="alert alert-success alert-dismissible fade show" role="alert">
        {{ session('success') }}
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif
@if (session('error'))
    <div class="alert alert-danger alert-dismissible fade show" role="alert">
        {{ session('error') }}
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif

<div class="row">
    <!-- Colonne gauche -->
    <div class="col-lg-4">
        <!-- Profil -->
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body text-center">
                <div class="mx-auto rounded-circle d-flex align-items-center justify-content-center mb-3" style="width: 80px; height: 80px; background-color: #E8F5E9; font-weight: 700; color: var(--benin-green); font-size: 30px;">
                    {{ strtoupper(substr($user->name, 0, 1)) }}
                </div>
                <h5 class="mb-1" style="color: var(--text-dark); font-weight: 700;">{{ $user->name }}</h5>
                <p class="mb-2" style="color: var(--text-muted);">{{ $user->email ?? '—' }}</p>
                <div class="mb-3">
                    @forelse ($user->roles as $role)
                        <span class="badge mr-1" style="background-color: {{ $role->pivot->is_active ? '#E8F5E9' : '#F1F3F4' }}; color: {{ $role->pivot->is_active ? 'var(--benin-green)' : 'var(--text-muted)' }}; font-weight: 600; padding: 5px 10px; border-radius: 8px;">
                            @if ($role->pivot->is_active) <i class="ti ti-check"></i> @endif {{ $role->name }}
                        </span>
                    @empty
                        <span class="text-muted">Aucun rôle</span>
                    @endforelse
                </div>
                <hr>
                <div class="text-left">
                    <p class="mb-2" style="color: var(--text-muted);"><i class="ti ti-mobile mr-2"></i>{{ $user->phone }}</p>
                    <p class="mb-2" style="color: var(--text-muted);"><i class="ti ti-world mr-2"></i>Locale : {{ strtoupper($user->locale) }}</p>
                    <p class="mb-2" style="color: var(--text-muted);">
                        <i class="ti ti-mobile mr-2"></i>Téléphone vérifié :
                        <strong style="color: {{ $user->phone_verified_at ? 'var(--benin-green)' : 'var(--benin-red)' }};">{{ $user->phone_verified_at ? 'Oui' : 'Non' }}</strong>
                    </p>
                    @if ($user->email_verified_at)
                        <p class="mb-2" style="color: var(--text-muted);"><i class="ti ti-email mr-2"></i>Email vérifié</p>
                    @endif
                    <p class="mb-0" style="color: var(--text-muted);"><i class="ti ti-calendar mr-2"></i>Inscrit le {{ $user->created_at?->format('d/m/Y H:i') }}</p>
                </div>
            </div>
        </div>

        <!-- Profils liés -->
        @if ($user->vendor)
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <p class="mb-2" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase; letter-spacing: 1px; font-weight: 600;">Profil vendeur</p>
                <div class="d-flex align-items-center justify-content-between">
                    <div>
                        <strong style="color: var(--text-dark);">{{ $user->vendor->business_name }}</strong>
                        <div>{!! \App\Support\AdminLabels::vendorStatusBadge($user->vendor->status) !!}</div>
                    </div>
                    <a href="{{ route('admin.vendors.show', $user->vendor) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                        <i class="ti ti-eye"></i>
                    </a>
                </div>
            </div>
        </div>
        @endif

        @if ($user->driverProfile)
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <p class="mb-2" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase; letter-spacing: 1px; font-weight: 600;">Profil livreur</p>
                <span class="badge" style="background-color: #E8F5E9; color: var(--benin-green); font-weight: 600; padding: 5px 10px; border-radius: 8px;">
                    {{ str_replace('driver-', '', $user->driverProfile->type) }} · {{ $user->driverProfile->status }}
                </span>
            </div>
        </div>
        @endif
    </div>

    <!-- Colonne droite -->
    <div class="col-lg-8">
        <!-- Statut du compte -->
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-header" style="background: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                <h5 class="mb-0" style="color: var(--text-dark); font-weight: 600;">Statut du compte</h5>
            </div>
            <div class="card-body">
                <form method="POST" action="{{ route('admin.users.status', $user) }}" class="row align-items-end">
                    @csrf
                    <div class="col-md-6">
                        <label style="color: var(--text-muted); font-size: 13px;">Changer le statut</label>
                        <select name="status" class="form-control">
                            @foreach (\App\Enums\UserStatus::cases() as $status)
                                <option value="{{ $status->value }}" @selected($user->status === $status->value)>{{ ucfirst($status->value) }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="col-md-6">
                        <button type="submit" class="btn btn-block" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                            <i class="ti ti-save"></i> Enregistrer
                        </button>
                    </div>
                </form>
            </div>
        </div>

        <!-- Rôles -->
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-header d-flex justify-content-between align-items-center" style="background: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                <h5 class="mb-0" style="color: var(--text-dark); font-weight: 600;">Rôles et permissions</h5>
                <small style="color: var(--text-muted);">Le premier rôle coché devient le rôle actif</small>
            </div>
            <div class="card-body">
                <form method="POST" action="{{ route('admin.users.roles', $user) }}">
                    @csrf
                    <div class="row">
                        @foreach ($roles as $role)
                            <div class="col-md-6">
                                <div class="custom-control custom-checkbox mb-3" style="border: 1px solid var(--border-color); border-radius: 10px; padding: 12px 12px 12px 42px;">
                                    <input type="checkbox" class="custom-control-input" id="role-{{ $role->id }}" name="roles[]" value="{{ $role->id }}"
                                        @checked($user->roles->contains('id', $role->id))>
                                    <label class="custom-control-label" for="role-{{ $role->id }}" style="cursor: pointer;">
                                        <strong style="color: var(--text-dark);">{{ $role->name }}</strong>
                                        <br><small style="color: var(--text-muted);">{{ $role->description }}</small>
                                    </label>
                                </div>
                            </div>
                        @endforeach
                    </div>
                    <button type="submit" class="btn" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-save"></i> Mettre à jour les rôles
                    </button>
                </form>
            </div>
        </div>

        <!-- Appareils -->
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-header" style="background: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                <h5 class="mb-0" style="color: var(--text-dark); font-weight: 600;">Appareils connectés</h5>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table mb-0">
                        <thead style="background-color: #F9FAFB;">
                            <tr>
                                <th class="border-0" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Plateforme</th>
                                <th class="border-0" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Version</th>
                                <th class="border-0" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Dernière activité</th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($user->devices as $device)
                                <tr>
                                    <td>{{ $device->platform }} <small class="text-muted">({{ $device->device_type ?? '—' }})</small></td>
                                    <td>{{ $device->app_version ?? '—' }}</td>
                                    <td>{{ $device->last_seen_at?->diffForHumans() ?? '—' }}</td>
                                </tr>
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