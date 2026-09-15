@extends('layouts.app')

@section('content')
<div class="row">
    <div class="col-md-12">
        <div class="card">
            <div class="card-body">
                <div class="text-center py-5">
                    <i class="ti ti-settings" style="font-size: 64px; color: #6c757d;"></i>
                    <h3 class="mt-3">{{ $section }}</h3>
                    <p class="text-muted mt-2">Cette section sera développée prochainement.</p>
                    <a href="{{ route('admin.dashboard') }}" class="btn btn-primary btn-sm mt-3">
                        <i class="ti ti-arrow-left"></i> Retour au tableau de bord
                    </a>
                </div>
            </div>
        </div>
    </div>
</div>
@endsection
