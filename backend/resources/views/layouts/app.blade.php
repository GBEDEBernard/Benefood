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
    <link href="https://fonts.googleapis.com/css?family=Roboto:300,400,500,700" rel="stylesheet">
    <link rel="stylesheet" type="text/css" href="{{ asset('assets/css/vendors.css') }}" />
    <link rel="stylesheet" type="text/css" href="{{ asset('assets/css/style.css') }}" />
    <link rel="stylesheet" type="text/css" href="{{ asset('assets/css/beninfood.css') }}" />
    
    <style>
        .app-main {
            padding: 30px;
            min-height: calc(100vh - 60px);
            margin-left: 250px;
            background: #F4F6F8;
        }
        @media (max-width: 991px) {
            .app-main { margin-left: 0; padding: 15px; }
        }
    </style>
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
    <script>
        // Fermer la sidebar mobile en cliquant sur l'overlay
        document.addEventListener('click', function(e) {
            if (window.innerWidth <= 991 && document.body.classList.contains('sidebar-toggled')) {
                var sidebar = document.querySelector('.app-navbar');
                var toggle = document.querySelector('.mobile-toggle');
                if (sidebar && !sidebar.contains(e.target) && toggle && !toggle.contains(e.target)) {
                    document.body.classList.remove('sidebar-toggled');
                }
            }
        });
    </script>
    @stack('scripts')
</body>

</html>