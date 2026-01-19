# 💾 Ondes.Storage - Stockage Local

Ce module permet de sauvegarder des données de manière persistante sur l'appareil de l'utilisateur.

> 🔒 **Isolation des données** : Chaque mini-app possède son propre espace de stockage sécurisé. Vous ne pouvez pas accéder aux données d'une autre application.

---

## `set(key, value)`
Sauvegarde une paire clé/valeur. Les données sont sérialisées automatiquement.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `key` | String | Clé d'identification unique. |
| `value` | Any | Donnée (String, Number, Boolean, Object, Array). |

```javascript
// Stocker un objet complexe
await Ondes.Storage.set('user_config', {
    darkMode: true,
    fontSize: 14,
    lastVisit: Date.now()
});
```

---

## `get(key)`
Récupère une valeur stockée.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `key` | String | La clé à rechercher. |

**Retourne** : `Promise<Any | null>` - La valeur originale ou `null` si non trouvée.

```javascript
const config = await Ondes.Storage.get('user_config');
if (config && config.darkMode) {
    applyDarkTheme();
}
```

---

## `remove(key)`
Supprime définitivement une entrée du stockage.

```javascript
await Ondes.Storage.remove('temp_cache');
```

---

## `clear()`
Efface **toutes** les données stockées pour cette application. À utiliser avec précaution.

```javascript
await Ondes.Storage.clear();
```

---

## `getKeys()`
Retourne la liste de toutes les clés existantes dans le stockage de l'app.

**Retourne** : `Promise<Array<String>>`

```javascript
const keys = await Ondes.Storage.getKeys();
console.log(`Vous avez ${keys.length} éléments sauvegardés.`);
```
