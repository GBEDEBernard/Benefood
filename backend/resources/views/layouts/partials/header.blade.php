<header class="navbar navbar-expand-lg navbar-light bg-light fixed-top">
    <div class="container-fluid">
        <a class="navbar-brand" href="/admin">Benefood Admin</a>
        <div class="d-flex">
            @auth
                <span class="me-2">{{ auth()->user()->name }}</span>
                <form method="POST" action="{{ route('logout') }}">
                    @csrf
                    <button class="btn btn-sm btn-outline-secondary">Logout</button>
                </form>
            @endauth
        </div>
    </div>
</header>
