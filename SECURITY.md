# 🛡️ Ondes Core Security Policy

## 🔒 Le modèle "Sandbox"

Ondes Core adopte un modèle de sécurité "Sandbox" strict pour protéger la vie privée des utilisateurs et l'intégrité du système. Chaque Mini-App exécute son code JavaScript dans un environnement isolé (WebView) et doit explicitement demander l'accès aux fonctionnalités natives sensibles via le `manifest.json`.

### Architecture

1.  **Isolation JavaScript** : Le code JavaScript des Mini-Apps n'a pas accès direct aux APIs natives. Il doit passer par le `OndesBridge`.
2.  **Manifest Déclaratif** : Chaque app déclare ses intentions dans le fichier `manifest.json` avec la clé `"permissions"`.
3.  **Approbation Utilisateur** : À la première ouverture, l'utilisateur doit valider explicitement les permissions demandées via une interface système sécurisée (inviolable par l'app).
4.  **Enforcement Natif** : Le code natif (Flutter) vérifie à chaque appel API sensible si la permission est accordée pour l'App ID appelant. Si non, l'appel est bloqué et une erreur est retournée.

## 📋 Permissions Disponibles

| Permission | Description | API JavaScript | Risque |
| :--- | :--- | :--- | :--- |
| `camera` | Accès à la caméra pour photo/vidéo | `Ondes.Device.scanQRCode`, `Ondes.Social.pickMedia` | 🔴 Élevé |
| `microphone` | Accès au microphone (enregistrement) | `Ondes.Device.recordAudio` | 🔴 Élevé |
| `location` | Géolocalisation GPS précise | `Ondes.Device.getGPSPosition` | 🔴 Élevé |
| `storage` | Accès aux fichiers du téléphone | `Ondes.Storage.readFile` | 🟠 Moyen |
| `contacts` | Lecture du carnet d'adresses | - | 🔴 Élevé |
| `friends` | Accès à la liste d'amis et graphe social | `Ondes.Friends.*` | 🟠 Moyen |
| `notifications` | Envoi de notifications push | - | 🟢 Faible |
| `bluetooth` | Scan et connexion périphériques | - | 🟠 Moyen |
| `social` | Interactions sociales (Like, Follow) | `Ondes.Social.*` | 🟢 Faible |

## 🛡️ Bonnes pratiques développeur

### 1. Principe de moindre privilège
Ne demandez que les permissions strictement nécessaires au fonctionnement de votre application. Une app "To-Do List" demandant l'accès à la `camera` paraîtra suspecte et sera probablement refusée par l'utilisateur.

### 2. Gestion des erreurs
Anticipez toujours le refus d'une permission.

```javascript
try {
  const code = await Ondes.Device.scanQRCode();
} catch (error) {
  if (error.message.includes("Permission denied")) {
    alert("L'accès à la caméra est nécessaire pour scanner un code.");
  }
}
```

### 3. Transparence
Expliquez à l'utilisateur pourquoi vous avez besoin d'une permission avant de déclencher l'action qui provoquera la demande système (si applicable, bien que dans Ondes la demande se fait au lancement).

## 🚨 Signalement de vulnérabilités

Si vous découvrez une faille de sécurité dans le système de Sandbox ou le Bridge, merci de ne pas la divulguer publiquement. Contactez l'équipe sécurité à `security@ondes.app`.
