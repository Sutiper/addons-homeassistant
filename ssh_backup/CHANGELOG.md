## 1.0.2 — 2026-05-09
- Correction accès OS host : full_access + nsenter avec tous les namespaces
- Correction bannière : support des retours à la ligne via \n
- Suppression options TCP/Agent forwarding (inutiles)
- Ajout option username configurable

## 1.0.1 — 2026-05-09
- Correction UsePAM et PrintLastLog non supportés par OpenSSH Alpine
- Passage à la base ghcr.io/home-assistant/base avec bashio
- Accès OS host via nsenter

## 1.0.0 — 2026-05-09
- Version initiale
- Support SSH + SFTP
- Authentification par clé publique, mot de passe ou les deux
- Mode SFTP uniquement
- Clés hôte persistantes
