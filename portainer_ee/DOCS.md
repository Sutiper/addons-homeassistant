# Portainer Business Edition

Portainer EE est une plateforme de gestion de conteneurs Docker avec interface web complète.

## Accès

Une fois démarré, accède à l'interface via :
- **HTTP** : `http://<ip-home-assistant>:9000`
- **HTTPS** : `https://<ip-home-assistant>:9443`

## Premier démarrage

Lors du premier démarrage, Portainer te demandera de créer un utilisateur administrateur.
Tu disposes de **5 minutes** pour le faire, sinon Portainer se ferme pour des raisons de sécurité — il suffit de redémarrer l'addon.

## Port Edge Agent

Le port **8000** est utilisé pour la communication avec les agents Edge
(comme l'addon `portainer_agent` de ce dépôt).

## Persistance des données

Toutes les données Portainer (configuration, utilisateurs, stacks) sont stockées
dans `/data` et persistent entre les redémarrages.
