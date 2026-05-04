# Portainer Edge Agent

Connecte ton Home Assistant à un serveur Portainer distant via un Edge Agent Standard.
La connexion est initiée depuis le Pi vers le serveur.

## Configuration

| Option | Description |
|--------|-------------|
| `edge_key` | Clé Edge générée par Portainer (obligatoire) |
| `edge_id` | Identifiant unique de cet environnement, ex: `homeassistant-rpi5` (obligatoire) |
| `edge_insecure_poll` | Désactive la vérification TLS (déconseillé) |
| `log_level` | `DEBUG`, `INFO`, `WARN` ou `ERROR` |

## Obtenir la clé Edge

1. Dans Portainer, va dans **Environments** → **Add environment**
2. Choisis **Docker Standalone** → **Edge Agent Standard**
3. Renseigne l'URL API et l'adresse du tunnel
4. Clique **Create** — copie la valeur `EDGE_KEY` de la commande générée
5. Colle-la dans le champ `edge_key` de cet addon

## Vérification

L'environnement doit passer en **Connected** dans Portainer après le démarrage.
