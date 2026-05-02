# Portainer Edge Agent

Cet addon connecte ton Home Assistant (Raspberry Pi 5) à un serveur Portainer distant
via un **Edge Agent Standard**. La connexion est initiée depuis le Pi vers le serveur —
le serveur n'a pas besoin d'atteindre directement ton HA.

## Pré-requis

Le serveur Portainer (`portainer.peda.ovh`) doit être accessible depuis le Pi 5
(ports **9443** et **8000** ouverts côté serveur).

## Configuration

| Option | Obligatoire | Description |
|--------|:-----------:|-------------|
| `portainer_url` | ✅ | URL HTTPS de ton Portainer (ex: `https://portainer.peda.ovh`) |
| `edge_key` | ✅ | Clé Edge générée par Portainer |
| `edge_id` | ✅ | Identifiant unique de cet environnement (ex: `homeassistant-pi5`) |
| `edge_insecure_poll` | ❌ | Désactive la vérification TLS (déconseillé) |
| `log_level` | ❌ | Niveau de log : `DEBUG`, `INFO`, `WARN`, `ERROR` |

## Obtenir la clé Edge (`edge_key`)

1. Dans Portainer, va dans **Environments** → **Add environment**
2. Choisis **Docker Standalone** → **Edge Agent Standard**
3. Renseigne l'**URL API** : `https://portainer.peda.ovh` et le **tunnel** : `portainer.peda.ovh:8000`
4. Clique sur **Create** — Portainer génère une commande `docker run` contenant `EDGE_KEY=...`
5. Copie cette valeur et colle-la dans le champ `edge_key` de cet addon

## Vérification

Une fois l'addon démarré, l'environnement doit passer en état **Connected** dans Portainer
dans les premières secondes.
