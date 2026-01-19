# 🔧 Guide d'installation

Ce guide vous explique comment configurer l'environnement de développement pour Ondes Core (Backend + App Mobile).

## Prérequis

Assurez-vous d'avoir installé les outils suivants :
- **Flutter 3.x** ([Guide d'installation](https://flutter.dev/docs/get-started/install))
- **Python 3.10+** ([Télécharger](https://www.python.org/downloads/))
- **Git**

## 1. Cloner le projet

Récupérez le code source depuis le dépôt :

```bash
git clone https://github.com/votre-repo/ondes-core.git
cd ondes-core
```

## 2. Configuration du Backend Django

Le backend est nécessaire pour que l'application fonctionne (login, chargement des apps, sociale, etc.).

```bash
# Se placer dans le dossier api
cd api

# Créer l'environnement virtuel (bonne pratique)
python -m venv venv

# Activer l'environnement
# macOS/Linux :
source venv/bin/activate
# Windows :
# venv\Scripts\activate

# Installer les dépendances
pip install -r requirements.txt

# Appliquer les migrations de base de données
python manage.py migrate

# Créer un compte administrateur (superuser) pour accéder au back-office
python manage.py createsuperuser
# (Suivez les instructions à l'écran)

# Lancer le serveur de développement
python manage.py runserver
```

Le serveur sera accessible à l'adresse **http://127.0.0.1:8000/**.

## 3. Lancer l'application Flutter

Gardez le terminal du backend ouvert et ouvrez-en un nouveau pour Flutter.

```bash
# Revenir à la racine du projet si vous étiez dans api/
cd ..

# Récupérer les dépendances Flutter
flutter pub get

# Lancer l'application
# Connectez un appareil ou lancez un émulateur avant
flutter run
```

## 4. Accès et Vérification

Une fois tout lancé, vous pouvez accéder aux services :

| Service | URL / Accès |
|---------|-----|
| **API Endpoint** | `http://127.0.0.1:8000/api/` |
| **Admin Django** | `http://127.0.0.1:8000/admin/` (Utilisez votre superuser) |
| **App Mobile** | Sur votre émulateur ou téléphone |
