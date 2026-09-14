<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Login - Béninfood</title>
    <link rel="stylesheet" href="{{ asset('assets/css/style.css') }}">
</head>
<body>
<div class="d-flex h-100 align-items-center justify-content-center" style="min-height:100vh;background:#f5f7fb;">
    <div class="card p-4" style="max-width:420px;width:100%;">
        <h3 class="mb-3">Connexion</h3>
        @if($errors->any())
            <div class="alert alert-danger">{{ $errors->first() }}</div>
        @endif
        <form method="POST" action="{{ route('login.post') }}">
            @csrf
            <div class="form-group">
                <label>Email</label>
                <input type="email" name="email" class="form-control" value="{{ old('email') }}" required autofocus>
            </div>
            <div class="form-group">
                <label>Mot de passe</label>
                <input type="password" name="password" class="form-control" required>
            </div>
            <div class="form-group mt-3">
                <button class="btn btn-primary btn-block" type="submit">Se connecter</button>
            </div>
        </form>
        <p class="mt-3 text-muted small">Utilisez un compte administrateur pour accéder au tableau de bord.</p>
    </div>
</div>
</body>
</html>
