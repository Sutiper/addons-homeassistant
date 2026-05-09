# SSH Primary — Documentation

Serveur SSH principal pour Home Assistant avec support SFTP complet.

## Dossiers accessibles

Une fois connecté, tu as accès aux dossiers suivants :

| Chemin | Contenu | Accès |
|--------|---------|-------|
| `/config` | Configuration Home Assistant (configuration.yaml, automations...) | Lecture/Écriture |
| `/data` | Données de l'add-on | Lecture/Écriture |
| `/share` | Dossier partagé entre add-ons | Lecture/Écriture |
| `/ssl` | Certificats SSL/TLS | Lecture seule |
| `/backup` | Sauvegardes HA | Lecture/Écriture |
| `/media` | Médias | Lecture/Écriture |
| `/addons` | Add-ons installés | Lecture seule |

## Configuration

### `username`
Nom d'utilisateur pour la connexion SSH. Par défaut `root`.

### `auth_mode`
Mode d'authentification :
- `key_only` — clé publique uniquement (recommandé)
- `password_only` — mot de passe uniquement
- `key_or_password` — les deux acceptés

### `authorized_keys`
Liste des clés publiques autorisées. Une clé par entrée.

### `password`
Mot de passe. Laissez vide si `auth_mode: key_only`.

### `sftp_enabled`
Active le sous-système SFTP. Activé par défaut.

### `sftp_only`
Restreint l'accès au SFTP uniquement, sans shell interactif.

### `log_level`
Niveau de verbosité : `DEBUG`, `INFO`, `WARNING`, `ERROR`.

### `banner`
Message affiché avant la connexion. Utiliser `\n` pour les retours à la ligne.

## Connexion

```bash
# SSH
ssh -p 22222 root@homeassistant.local

# SFTP
sftp -P 22222 root@homeassistant.local

# Par clé publique
ssh -i ~/.ssh/ma_cle -p 22222 root@homeassistant.local
```
