<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>JWY — Paiement</title>
    <style>
        body { font-family: -apple-system, system-ui, sans-serif; background: #F5F8FC; color: #1a1a1a;
               display: flex; min-height: 100vh; margin: 0; align-items: center; justify-content: center; }
        .carte { background: #fff; border-radius: 16px; padding: 32px 24px; max-width: 360px; margin: 16px;
                 text-align: center; box-shadow: 0 4px 16px rgba(0,0,0,.06); }
        h1 { font-size: 20px; color: {{ $succes ? '#1565C0' : '#B00020' }}; }
        p { color: #555; line-height: 1.5; }
    </style>
</head>
<body>
    <div class="carte">
        <h1>{{ $succes ? 'Paiement envoyé' : 'Paiement non abouti' }}</h1>
        <p>{{ $succes
            ? 'Retournez dans l’application JWY : la confirmation s’affichera dans quelques secondes.'
            : 'Retournez dans l’application JWY pour réessayer.' }}</p>
    </div>
</body>
</html>
