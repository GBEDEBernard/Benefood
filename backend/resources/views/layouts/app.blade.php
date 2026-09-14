<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Admin - Benefood</title>
    <link rel="stylesheet" href="{{ asset('admin-assets/css/style.css') }}">
    @stack('styles')
    <style>body{padding-top:60px;}</style>
</head>
<body>
    @include('layouts.partials.header')

    <main class="container">
        @yield('content')
    </main>

    @include('layouts.partials.footer')

    <script src="{{ asset('admin-assets/js/app.js') }}"></script>
    @stack('scripts')
</body>
</html>
