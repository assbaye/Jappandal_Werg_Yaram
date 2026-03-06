# Jappandal Werg Yaram — Backend API

Plateforme de santé communautaire sénégalaise.
**Stack** : Laravel 11 · Lighthouse (GraphQL) · PostgreSQL · JWT Auth

---

## Installation

```bash
# 1. Cloner et installer les dépendances
composer install

# 2. Configuration
cp .env.example .env
php artisan key:generate
php artisan jwt:secret

# 3. Base de données PostgreSQL
createdb jwy_db
php artisan migrate
php artisan db:seed

# 4. Publier les configs
php artisan vendor:publish --provider="Nuwave\Lighthouse\LighthouseServiceProvider" --tag=config
php artisan vendor:publish --provider="Tymon\JWTAuth\Providers\LaravelServiceProvider"
php artisan vendor:publish --provider="BeyondCode\LaravelWebSockets\WebSocketsServiceProvider" --tag="migrations"
php artisan vendor:publish --provider="Spatie\Permission\PermissionServiceProvider"

# 5. Démarrer les serveurs
php artisan serve               # API sur :8000
php artisan websockets:serve    # WebSockets sur :6001
php artisan queue:work          # Worker de queue
```

---

## GraphQL Playground

Accéder à : `http://localhost:8000/graphql-playground`

### Exemples de requêtes

**Inscription**
```graphql
mutation {
  register(input: {
    email: "aminata@example.sn"
    password: "secret123"
    telephone: "+221771234567"
    role: "patient"
    nom: "Diallo"
    prenom: "Aminata"
    date_naissance: "1990-05-15"
    genre: "F"
    groupe_sanguin: "O+"
  }) {
    access_token
    user { id email role }
  }
}
```

**Connexion**
```graphql
mutation {
  login(email: "aminata@example.sn", password: "secret123") {
    access_token
    user { id email role patient { nom_complet } }
  }
}
```

**Pharmacies proches**
```graphql
query {
  pharmaciesProches(latitude: 14.6928, longitude: -17.4467, rayon: 5) {
    id nom_pharmacie adresse distance
    stocks {
      medicament { nom_commercial }
      quantite_disponible prix_vente
    }
  }
}
```

**Demander une consultation**
```graphql
# Header: Authorization: Bearer {token}
mutation {
  demanderConsultation(input: {
    medecin_id: "1"
    type_consultation: VIDEO
    symptomes: "Fièvre et maux de tête depuis 2 jours"
  }) {
    id statut date_consultation
    medecin { nom_complet specialite }
  }
}
```

**Démarrer l'appel vidéo**
```graphql
mutation {
  demarrerTeleConsultation(consultation_id: "1") {
    agora_channel
    agora_token
    agora_app_id
  }
}
```

---

## Architecture

```
app/
├── Models/                  # 15 modèles Eloquent
├── GraphQL/
│   ├── Mutations/           # Register, Login, DemanderConsultation, etc.
│   ├── Queries/             # PharmaciesProches, MesConsultations, etc.
│   └── Subscriptions/       # StatutConsultation, NouvelleNotification
├── Services/
│   ├── AgoraService.php     # Génération tokens RTC vidéo
│   ├── PaymentService.php   # Orange Money + Wave + Stripe
│   └── NotificationService.php
graphql/
├── schema.graphql           # Point d'entrée (imports)
├── enums.graphql
├── auth.graphql
├── patient.graphql
├── medecin.graphql
├── pharmacie.graphql
├── consultation.graphql
├── prescription.graphql
├── paiement.graphql
├── notification.graphql
└── administration.graphql
database/migrations/         # 21 fichiers de migration
```

---

## Variables d'environnement clés

| Variable | Description |
|---|---|
| `AGORA_APP_ID` | App ID Agora.io |
| `AGORA_APP_CERTIFICATE` | Certificat Agora.io |
| `STRIPE_SECRET` | Clé secrète Stripe |
| `ORANGE_MONEY_AUTH_TOKEN` | Token API Orange Money SN |
| `WAVE_API_KEY` | Clé API Wave SN |
| `JWT_SECRET` | Secret JWT (généré par `php artisan jwt:secret`) |

---

## Flutter (Frontend — à venir)

Le client Flutter utilisera :
- Package `graphql_flutter` pour les queries/mutations/subscriptions
- Package `agora_rtc_engine` pour la téléconsultation vidéo
- Package `flutter_stripe` pour les paiements Stripe
- WebSocket via `web_socket_channel` pour les notifications temps réel
