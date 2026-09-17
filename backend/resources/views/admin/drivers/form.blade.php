@extends('layouts.app')

@section('content')
<x-admin.page-header title="Créer un livreur" subtitle="Phase 16 — Livreur interne Beninfood" :back="route('admin.drivers.index')">
</x-admin.page-header>

@if (session('error'))
    <div class="alert alert-danger alert-dismissible fade show" role="alert">
        {{ session('error') }}
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif

<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px; max-width: 720px;">
    <div class="card-body">
        <form method="POST" action="{{ route('admin.drivers.store') }}">
            @csrf
            <div class="form-group mb-3">
                <label for="name" class="font-weight-600" style="color: var(--text-dark);">Nom complet *</label>
                <input type="text" id="name" name="name" value="{{ old('name') }}" class="form-control @error('name') is-invalid @enderror" required>
                @error('name')<div class="invalid-feedback">{{ $message }}</div>@enderror
            </div>
            <div class="form-group mb-3">
                <label for="phone" class="font-weight-600" style="color: var(--text-dark);">Téléphone *</label>
                <input type="text" id="phone" name="phone" value="{{ old('phone') }}" class="form-control @error('phone') is-invalid @enderror" placeholder="+229..." required>
                @error('phone')<div class="invalid-feedback">{{ $message }}</div>@enderror
            </div>
            <div class="form-group mb-3">
                <label for="vehicle" class="font-weight-600" style="color: var(--text-dark);">Véhicule</label>
                <input type="text" id="vehicle" name="vehicle" value="{{ old('vehicle') }}" class="form-control" placeholder="Moto, Tricycle, Vélo...">
            </div>
            <div class="form-group mb-4">
                <label for="password" class="font-weight-600" style="color: var(--text-dark);">Mot de passe initial</label>
                <input type="text" id="password" name="password" value="{{ old('password') }}" class="form-control" placeholder="Laisser vide pour un mot de passe généré">
            </div>
            <div class="d-flex align-items-center">
                <button type="submit" class="btn mr-2" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                    <i class="ti ti-plus"></i> Créer le livreur
                </button>
                <a href="{{ route('admin.drivers.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                    Annuler
                </a>
            </div>
        </form>
    </div>
</div>
@endsection