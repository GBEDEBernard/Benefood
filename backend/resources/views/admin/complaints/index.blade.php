@extends('layouts.app')

@section('content')
<x-admin.page-header title="Réclamations & litiges" subtitle="Phase 16 — Traitement des réclamations">
    <a href="{{ route('admin.dashboard') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
        <i class="ti ti-home"></i> Dashboard
    </a>
</x-admin.page-header>

@if (session('success'))
    <div class="alert alert-success alert-dismissible fade show" role="alert">
        {{ session('success') }}
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif

@php
    $statusChips = [
        ['key' => '', 'label' => 'Toutes', 'count' => $counts['all'], 'fg' => 'var(--benin-green)'],
        ['key' => 'open', 'label' => 'Ouvertes', 'count' => $counts['open'], 'fg' => 'var(--benin-red)'],
        ['key' => 'in_progress', 'label' => 'En cours', 'count' => $counts['in_progress'], 'fg' => 'var(--benin-orange)'],
        ['key' => 'closed', 'label' => 'Clôturées', 'count' => $counts['closed'], 'fg' => 'var(--benin-green)'],
    ];
@endphp
<div class="row mb-4">
    <div class="col-12">
        <ul class="nav" style="gap: 8px; flex-wrap: wrap; list-style: none; padding: 0; margin: 0;">
            @foreach ($statusChips as $chip)
                <li class="nav-item">
                    <a class="btn btn-sm"
                       href="{{ route('admin.complaints.index', array_merge(['status' => $chip['key'] ?: null, 'q' => $filters['q'] ?? null])) }}"
                       style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ ($filters['status'] ?? '') === $chip['key'] ? 'background-color: '.$chip['fg'].'; color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                        {{ $chip['label'] }} <span class="ml-1" style="font-weight: 700;">{{ $chip['count'] }}</span>
                    </a>
                </li>
            @endforeach
        </ul>
    </div>
</div>

<form method="GET" action="{{ route('admin.complaints.index') }}">
    @if (! empty($filters['status']))
        <input type="hidden" name="status" value="{{ $filters['status'] }}">
    @endif
    <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
        <div class="card-body py-3">
            <div class="row align-items-center">
                <div class="col-md-8">
                    <input type="text" name="q" value="{{ $filters['q'] ?? '' }}" class="form-control" placeholder="Sujet, type, client, référence commande...">
                </div>
                <div class="col-md-4 d-flex">
                    <button type="submit" class="btn mr-2" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-search"></i> Filtrer
                    </button>
                    <a href="{{ route('admin.complaints.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                        Réinitialiser
                    </a>
                </div>
            </div>
        </div>
    </div>
</form>

<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table table-hover mb-0">
                <thead style="background-color: #F9FAFB;">
                    <tr>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Sujet</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Type</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Client</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Commande</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Ouverte le</th>
                        <th class="border-0 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($complaints as $complaint)
                        <tr>
                            <td class="py-3" style="font-weight: 600; color: var(--text-dark);">{{ $complaint->subject }}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ ucfirst($complaint->type) }}</td>
                            <td class="py-3" style="color: var(--text-dark);">{{ $complaint->user?->name ?? '—' }}</td>
                            <td class="py-3">
                                @if ($complaint->order)
                                    <a href="{{ route('admin.orders.show', $complaint->order) }}" style="color: var(--benin-green); font-family: monospace;">{{ $complaint->order->reference }}</a>
                                @else
                                    <span style="color: var(--text-muted);">—</span>
                                @endif
                            </td>
                            <td class="py-3">{!! \App\Support\AdminLabels::complaintStatusBadge($complaint->status->value) !!}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $complaint->created_at?->format('d/m/Y') ?? '—' }}</td>
                            <td class="py-3 text-right">
                                <a href="{{ route('admin.complaints.show', $complaint) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                    <i class="ti ti-eye"></i> Traiter
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="7" class="text-center py-5" style="color: var(--text-muted);">
                                <i class="ti ti-headphone" style="font-size: 40px;"></i>
                                <p class="mt-2 mb-0">Aucune réclamation trouvée.</p>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @if ($complaints->hasPages())
        <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px;">
            {{ $complaints->links() }}
        </div>
    @endif
</div>
@endsection