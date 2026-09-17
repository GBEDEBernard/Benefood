@extends('layouts.app')

@section('content')
<x-admin.page-header title="Journal d'audit" subtitle="Phase 16 — Audit des actions sensibles (append-only)">
    <form method="GET" action="{{ route('admin.audit.export') }}" target="_blank">
        @if (! empty($filters['action']))
            <input type="hidden" name="action" value="{{ $filters['action'] }}">
        @endif
        @if (! empty($filters['entity_type']))
            <input type="hidden" name="entity_type" value="{{ $filters['entity_type'] }}">
        @endif
        @if (! empty($filters['from']))
            <input type="hidden" name="from" value="{{ $filters['from'] }}">
        @endif
        @if (! empty($filters['to']))
            <input type="hidden" name="to" value="{{ $filters['to'] }}">
        @endif
        <button type="submit" class="btn btn-sm" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
            <i class="ti ti-download"></i> Exporter CSV
        </button>
    </form>
</x-admin.page-header>

<form method="GET" action="{{ route('admin.audit.index') }}">
    <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
        <div class="card-body py-3">
            <div class="row align-items-center">
                <div class="col-md-4">
                    <input type="text" name="q" value="{{ $filters['q'] ?? '' }}" class="form-control" placeholder="Action, entité, acteur...">
                </div>
                <div class="col-md-2">
                    <select name="entity_type" class="form-control">
                        <option value="">Toutes les entités</option>
                        @foreach ($entityTypes as $type)
                            <option value="{{ $type }}" @selected(($filters['entity_type'] ?? '') === $type)>{{ ucfirst($type) }}</option>
                        @endforeach
                    </select>
                </div>
                <div class="col-md-2">
                    <input type="date" name="from" value="{{ $filters['from'] ?? '' }}" class="form-control" title="Du">
                </div>
                <div class="col-md-2">
                    <input type="date" name="to" value="{{ $filters['to'] ?? '' }}" class="form-control" title="Au">
                </div>
                <div class="col-md-2 d-flex">
                    <button type="submit" class="btn mr-2" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-search"></i> Filtrer
                    </button>
                    <a href="{{ route('admin.audit.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
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
            <table class="table table-hover mb-0" style="font-size: 13px;">
                <thead style="background-color: #F9FAFB;">
                    <tr>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Date</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Acteur</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Action</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Entité</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">IP</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($logs as $log)
                        <tr>
                            <td class="py-3" style="color: var(--text-muted);">{{ $log->created_at?->format('d/m/Y H:i') ?? '—' }}</td>
                            <td class="py-3" style="color: var(--text-dark);">
                                <span style="font-family: monospace;">{{ $log->actor_type ?? 'system' }} {{ $log->actor_id ?? '' }}</span>
                            </td>
                            <td class="py-3"><span style="font-weight: 600; color: var(--text-dark);">{{ $log->action }}</span></td>
                            <td class="py-3">
                                @if ($log->entity_type)
                                    <span style="color: var(--text-muted);">{{ $log->entity_type }}</span>
                                    <small style="color: var(--text-muted); font-family: monospace;">{{ $log->entity_id }}</small>
                                @else
                                    <span style="color: var(--text-muted);">—</span>
                                @endif
                            </td>
                            <td class="py-3" style="color: var(--text-muted); font-family: monospace;">{{ $log->ip ?? '—' }}</td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5" class="text-center py-5" style="color: var(--text-muted);">
                                <i class="ti ti-shield" style="font-size: 40px;"></i>
                                <p class="mt-2 mb-0">Aucune entrée d'audit trouvée.</p>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @if ($logs->hasPages())
        <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px;">
            {{ $logs->links() }}
        </div>
    @endif
</div>
@endsection