@extends('layouts.app')

@section('content')
<x-admin.page-header title="{{ $complaint->subject }}" subtitle="Type {{ $complaint->type }} — ouverte {{ $complaint->created_at?->format('d/m/Y H:i') }}" :back="route('admin.complaints.index')">
    {!! \App\Support\AdminLabels::complaintStatusBadge($complaint->status->value) !!}
</x-admin.page-header>

@if (session('success'))
    <div class="alert alert-success alert-dismissible fade show" role="alert">
        {{ session('success') }}
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif

<div class="row">
    <div class="col-md-8">
        <!-- Conversation -->
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Conversation</h6>
                <div class="mb-4 p-3 rounded" style="background-color: #F9FAFB; border-left: 4px solid var(--benin-orange);">
                    <small style="color: var(--text-muted);">{{ $complaint->user?->name }} — {{ $complaint->created_at?->format('d/m/Y H:i') }}</small>
                    <p class="mb-0 mt-1" style="color: var(--text-dark);">{{ $complaint->description }}</p>
                </div>
                @forelse ($complaint->messages()->orderBy('created_at')->get() as $message)
                    <div class="mb-3 p-3 rounded" style="background-color: {{ $message->sender_type === 'admin' ? '#E8F5E9' : '#F9FAFB' }}; border-left: 4px solid {{ $message->sender_type === 'admin' ? 'var(--benin-green)' : 'var(--text-muted)' }};">
                        <small style="color: var(--text-muted);">{{ $message->sender_type === 'admin' ? 'Porteuse / Support' : 'Client' }} — {{ $message->created_at?->format('d/m/Y H:i') }}</small>
                        <p class="mb-0 mt-1" style="color: var(--text-dark);">{{ $message->message }}</p>
                    </div>
                @empty
                    <p style="color: var(--text-muted);">Aucun échange pour l'instant.</p>
                @endforelse
            </div>
        </div>

        @if ($canResolve && $complaint->status->value !== 'closed')
            <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                <div class="card-body">
                    <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Répondre au client</h6>
                    <form method="POST" action="{{ route('admin.complaints.reply', $complaint) }}">
                        @csrf
                        <div class="form-group mb-3">
                            <textarea name="message" rows="3" class="form-control" required maxlength="2000" placeholder="Votre réponse..."></textarea>
                        </div>
                        <button type="submit" class="btn" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                            <i class="ti ti-send"></i> Envoyer la réponse
                        </button>
                    </form>
                </div>
            </div>

            <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                <div class="card-body">
                    <div class="d-flex flex-wrap align-items-center" style="gap: 10px;">
                        @if ($complaint->status->value !== 'in_progress')
                            <form method="POST" action="{{ route('admin.complaints.in-progress', $complaint) }}">
                                @csrf
                                <button type="submit" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                    <i class="ti ti-player-play"></i> Prendre en charge
                                </button>
                            </form>
                        @endif
                        <form method="POST" action="{{ route('admin.complaints.close', $complaint) }}"
                              onsubmit="return confirm('Clôturer cette réclamation ?');">
                            @csrf
                            <div class="d-flex align-items-center" style="gap: 8px;">
                                <input type="text" name="resolution" class="form-control" placeholder="Résolution (optionnel)" style="min-width: 220px;">
                                <button type="submit" class="btn" style="background-color: var(--benin-red); color: #FFFFFF; border-radius: 8px;">
                                    <i class="ti ti-lock"></i> Clôturer
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        @endif
    </div>

    <div class="col-md-4">
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Informations</h6>
                <ul class="list-unstyled mb-0" style="font-size: 14px;">
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Client</span><strong>{{ $complaint->user?->name ?? '—' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Téléphone</span><strong>{{ $complaint->user?->phone ?? '—' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Commande</span>
                        <strong>
                            @if ($complaint->order)
                                <a href="{{ route('admin.orders.show', $complaint->order) }}" style="color: var(--benin-green); font-family: monospace;">{{ $complaint->order->reference }}</a>
                            @else
                                —
                            @endif
                        </strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Type</span><strong>{{ ucfirst($complaint->type) }}</strong></li>
                    @if ($complaint->closed_at)
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Clôturée le</span><strong>{{ $complaint->closed_at->format('d/m/Y H:i') }}</strong></li>
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Par</span><strong>{{ $complaint->closer?->name ?? '—' }}</strong></li>
                    @endif
                    @if ($complaint->resolution)
                        <li class="py-1 pt-2"><span style="color: var(--text-muted);">Résolution</span>
                            <p class="mb-0 mt-1" style="color: var(--text-dark); background: #F9FAFB; border-radius: 8px; padding: 8px;">{{ $complaint->resolution }}</p>
                        </li>
                    @endif
                </ul>
            </div>
        </div>
    </div>
</div>
@endsection