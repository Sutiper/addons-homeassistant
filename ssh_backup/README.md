# SSH Backup

Serveur SSH de secours pour Home Assistant avec support SFTP complet.
Identique à SSH Primary mais sur un port différent (22223 par défaut).

- Authentification par clé publique, mot de passe ou les deux
- Support SFTP natif
- Mode SFTP uniquement (avec chroot)
- Clés hôte persistantes entre les redémarrages
- TCP/Agent forwarding configurable
- Bannière de connexion optionnelle
