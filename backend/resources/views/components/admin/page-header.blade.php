<div class="row">
    <div class="col-md-12 m-b-30">
        <div class="d-block d-lg-flex flex-nowrap align-items-center justify-content-between">
            <div class="d-flex align-items-center">
                @if (! empty($back))
                    <a href="{{ $back }}" class="btn btn-sm mr-3 d-flex align-items-center justify-content-center" style="width: 38px; height: 38px; background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 10px; color: var(--text-dark);">
                        <i class="ti ti-arrow-left"></i>
                    </a>
                @endif
                <div class="page-title {{ ! empty($back) ? '' : 'mr-4 pr-4 border-right' }}">
                    <h1 style="color: var(--text-dark); font-weight: 700; margin-bottom: 2px;">{{ $title }}</h1>
                    @if (! empty($subtitle))
                        <small style="color: var(--text-muted);">{{ $subtitle }}</small>
                    @endif
                </div>
            </div>
            <div class="d-flex align-items-center">{{ $slot }}</div>
        </div>
    </div>
</div>