<!DOCTYPE html>
<html lang="fr">

<head>
    <title>Béninfood — Back-office</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
    <meta name="description" content="Back-office Béninfood — Gestion du marketplace alimentaire" />
    <meta name="author" content="Béninfood" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <link rel="icon" href="{{ asset('assets/img/logo.jpeg') }}" type="image/jpeg">
    <script>
        try {
            if (window.localStorage.getItem('bf.sidebar.collapsed') === '1') {
                document.documentElement.classList.add('bf-sidebar-collapsed');
            }
        } catch (error) {}
    </script>
    <link href="https://fonts.googleapis.com/css?family=Roboto:300,400,500,700" rel="stylesheet">
    <link rel="stylesheet" type="text/css" href="{{ asset('assets/css/vendors.css') }}" />
    <link rel="stylesheet" type="text/css" href="{{ asset('assets/css/style.css') }}" />
    <link rel="stylesheet" type="text/css" href="{{ asset('assets/css/beninfood.css') }}" />
    <link rel="stylesheet" type="text/css" href="{{ asset('assets/css/admin-premium.css') }}" />
    @stack('styles')
</head>

<body>
    <div class="app">
        <div class="app-wrap">
            <div class="loader">
                <div class="h-100 d-flex justify-content-center">
                    <div class="align-self-center">
                        <img src="{{ asset('assets/img/loader/loader.svg') }}" alt="Chargement...">
                    </div>
                </div>
            </div>

            @include('layouts.header')
            @include('layouts.sidebar')

            <main class="app-main" id="main">
                <div class="container-fluid">
                    @yield('content')
                </div>
            </main>

            @include('layouts.footer')
        </div>
    </div>

    <script src="{{ asset('assets/js/vendors.js') }}"></script>
    <script src="{{ asset('assets/js/app.js') }}"></script>
    <script src="{{ asset('assets/js/admin-shell.js') }}"></script>
    @stack('scripts')
</body>

</html>