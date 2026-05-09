# SSH Backup — Documentation

Serveur SSH de secours pour Home Assistant avec support SFTP complet.
Identique à SSH Primary mais sur un port différent (**22223** par défaut).

Utilisez cet add-on comme accès de secours si le port principal est inaccessible.

## Configuration

### `auth_mode`
Mode d'authentification :
- `key_only` — clé publique uniquement (recommandé)
- `password_only` — mot de passe uniquement
- `key_or_password` — les deux acceptés

### `authorized_keys`
Liste des clés publiques autorisées à se connecter. Une clé par entrée.

### `password`
Mot de passe pour l'utilisateur `hassio`. Laissez vide si `auth_mode: key_only`.

### `allow_root_login`
Autorise la connexion en tant que root. **Non recommandé.**

### `allow_tcp_forwarding`
Autorise le forwarding de ports TCP (`-L`, `-R`). Désactivé par défaut.

### `allow_agent_forwarding`
Autorise le forwarding de l'agent SSH. Désactivé par défaut.

### `sftp_enabled`
Active le sous-système SFTP. Activé par défaut.

### `sftp_only`
Restreint l'utilisateur au SFTP uniquement, sans accès shell.

### `log_level`
Niveau de verbosité des logs : `DEBUG`, `INFO`, `WARNING`, `ERROR`.

### `banner`
Message affiché avant la connexion. Laissez vide pour désactiver.

## Connexion

```bash
# Par clé publique
ssh -i ~/.ssh/ma_cle -p 22223 hassio@homeassistant.local

# SFTP
sftp -i ~/.ssh/ma_cle -P 22223 hassio@homeassistant.local
```

## Notes

- Les clés hôte SSH sont persistantes et stockées dans `/data/ssh/`
- Le port par défaut est **22223** (modifiable dans l'onglet Réseau)
- Cet add-on est indépendant de SSH Primary — il a ses propres clés hôte
