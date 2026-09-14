<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Register - Béninfood</title>
    <link rel="stylesheet" href="{{ asset('assets/css/style.css') }}">
</head>
<body>
<div class="d-flex h-100 align-items-center justify-content-center" style="min-height:100vh;background:#f5f7fb;">
    <div class="card p-4" style="max-width:480px;width:100%;">
        <h3 class="mb-3">Inscription</h3>
        @if($errors->any())
            <div class="alert alert-danger">{{ $errors->first() }}</div>
        @endif
        <form method="POST" action="{{ route('register.post') }}">
            @csrf
            <div class="form-group">
                <label>Nom</label>
                <input type="text" name="name" class="form-control" value="{{ old('name') }}" required autofocus>
            </div>
            <div class="form-group">
                <label>Email</label>
                <input type="email" name="email" class="form-control" value="{{ old('email') }}" required>
            </div>
            <div class="form-group">
                <label>Mot de passe</label>
                <input type="password" name="password" class="form-control" required>
            </div>
            <div class="form-group">
                <label>Confirmer mot de passe</label>
                <input type="password" name="password_confirmation" class="form-control" required>
            </div>
            <div class="form-group mt-3">
                <button class="btn btn-primary btn-block" type="submit">S'inscrire</button>
            </div>
        </form>
        <p class="mt-3 small">Vous avez déjà un compte ? <a href="{{ route('login') }}">Se connecter</a></p>
    </div>
</div>
</body>
</html>
