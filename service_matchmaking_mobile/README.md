# Service Matchmaking Mobile

Application mobile Flutter pour la plateforme de mise en relation entre clients et prestataires de services.

## Apercu

Ce projet est le client mobile de l'application Service Matchmaking.

Fonctionnalites principales:
- Authentification (connexion, inscription, mot de passe oublie)
- Gestion du profil utilisateur
- Creation et suivi des demandes de service
- Consultation des propositions
- Messagerie et conversations
- Notifications

## Stack technique

- Flutter
- Dart (SDK `^3.12.0`)
- BLoC (`flutter_bloc`, `bloc`)
- Navigation (`go_router`)
- HTTP (`dio`)
- Stockage securise (`flutter_secure_storage`)
- WebSocket (`web_socket_channel`)

## Prerequis

Assurez-vous d'avoir installe:
- Flutter SDK
- Dart SDK (inclus avec Flutter)
- Android Studio et/ou Xcode (selon la plateforme cible)

Verifier l'environnement:

```bash
flutter --version
flutter doctor
```

## Installation

Depuis le dossier `service_matchmaking_mobile`:

```bash
flutter pub get
```

## Configuration

L'URL de l'API est configuree via `--dart-define`.

Variable disponible:
- `API_BASE_URL`: URL de base du backend

Exemple:

```bash
flutter run --dart-define=API_BASE_URL=https://votre-api.exemple.com
```

Note: si aucune valeur n'est fournie, une valeur par defaut est utilisee dans le code.

## Lancer le projet

```bash
flutter run
```

Pour cibler un appareil specifique:

```bash
flutter devices
flutter run -d <device_id>
```

## Build release

Android (APK):

```bash
flutter build apk --release
```

Android (App Bundle):

```bash
flutter build appbundle --release
```

iOS:

```bash
flutter build ios --release
```

## Qualite du code

Analyser:

```bash
flutter analyze
```

Executer les tests:

```bash
flutter test
```

## Structure du projet

```text
lib/
	app/        # configuration globale (app, theme, router)
	core/       # utilitaires partages (network, erreurs, constantes, widgets)
	features/   # modules fonctionnels (auth, requests, messages, notifications)
	main.dart   # point d'entree
```

## Publication GitHub

Avant de publier:
- Verifier qu'aucune cle API, token ou secret n'est versionne
- Verifier la configuration de l'URL backend (`API_BASE_URL`)
- Ajouter des captures d'ecran dans un dossier `screenshots/` (optionnel mais recommande)
- Mettre a jour ce README si de nouvelles fonctionnalites sont ajoutees

## Ressources utiles

- Documentation Flutter: https://docs.flutter.dev/
- Packages Dart/Flutter: https://pub.dev/
