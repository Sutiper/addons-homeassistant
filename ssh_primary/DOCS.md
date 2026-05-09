# SSH Primary — Documentation

Serveur SSH principal pour Home Assistant avec support SFTP complet.

## Configuration

### `auth_mode`
Mode d'authentification :
- `key_only` — clé publique uniquement (recommandé)
- `password_only` — mot de passe uniquement
- `key_or_password` — les deux acceptés

### `authorized_keys`
Liste des clés publiques autorisées à se connecter. Une clé par entrée.

Exemple :
```
ssh-ed25519 AAAA... tom@machine
ssh-rsa AAAA... backup-key
```

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
Le répertoire personnel devient `/home/hassio/data/`.

### `log_level`
Niveau de verbosité des logs : `DEBUG`, `INFO`, `WARNING`, `ERROR`.

### `banner`
Message affiché avant la connexion. Laissez vide pour désactiver.

## Connexion

```bash
# Par clé publique
ssh -i ~/.ssh/ma_cle -p 22222 hassio@homeassistant.local

# SFTP
sftp -i ~/.ssh/ma_cle -P 22222 hassio@homeassistant.local
```

## Notes

- Les clés hôte SSH sont persistantes et stockées dans `/data/ssh/`
- Le port par défaut est **22222** (modifiable dans l'onglet Réseau)
- Pour un accès depuis internet, tunneler via FRP sur le VPS
