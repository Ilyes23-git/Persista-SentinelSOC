# deploy_wazuh.sh

Script bash qui clone le dépôt officiel [`wazuh/wazuh-docker`](https://github.com/wazuh/wazuh-docker) et déploie la stack Wazuh (**manager + indexer + dashboard**) en mode `single-node` via Docker Compose.

## Prérequis

| Outil | Vérification |
|---|---|
| Git | `git --version` |
| Docker | `docker --version` |
| Docker Compose (v2 plugin ou v1) | `docker compose version` ou `docker-compose --version` |
| Accès au daemon Docker | l'utilisateur doit être dans le groupe `docker`, ou lancer le script avec `sudo` |

Le script vérifie ces prérequis automatiquement au démarrage et s'arrête avec un message clair si l'un d'eux manque.

## Installation

```bash
# 1. Récupérer le script (ou le copier depuis ce dépôt)
chmod +x deploy_wazuh.sh

# 2. Lancer le déploiement
./deploy_wazuh.sh
```

> Le script ajuste `vm.max_map_count` via `sysctl`, ce qui nécessite les droits root. S'il n'est pas déjà lancé en root, il basculera automatiquement sur `sudo` pour cette seule étape.

## Usage

```bash
./deploy_wazuh.sh [TAG] [INSTALL_DIR]
```

| Argument | Description | Défaut |
|---|---|---|
| `TAG` | Tag/branche du dépôt `wazuh-docker` à cloner | `v4.14.6` |
| `INSTALL_DIR` | Répertoire où cloner le dépôt | `./wazuh-docker` |

**Exemples :**

```bash
./deploy_wazuh.sh                       # version par défaut
./deploy_wazuh.sh v4.14.3               # forcer une version précise
./deploy_wazuh.sh v4.14.6 /opt/wazuh    # + répertoire personnalisé
```

## Ce que fait le script, étape par étape

1. **`check_dependencies`** — vérifie `git`, `docker`, la disponibilité de `docker compose`/`docker-compose`, et que le daemon Docker répond.
2. **`tune_system`** — relève `vm.max_map_count` à `262144`. Sans ce réglage, le conteneur **Wazuh Indexer** (basé sur OpenSearch) échoue silencieusement au démarrage — c'est la cause la plus fréquente d'un déploiement qui reste bloqué.
3. **`clone_repo`** — clone `wazuh/wazuh-docker` sur le tag demandé. Si le dossier existe déjà, cette étape est sautée (pas de re-clone destructif).
4. **`generate_certs`** — génère les certificats SSL inter-composants via `generate-indexer-certs.yml`. Sauté si des certificats existent déjà dans `config/wazuh_indexer_ssl_certs`.
5. **`start_containers`** — `docker compose up -d`, puis attend ~15s le temps que l'indexer démarre.
6. **`verify_deployment`** — affiche l'état des conteneurs, l'URL du dashboard et les identifiants par défaut.

## Accès au Dashboard

Une fois le déploiement terminé :

- URL : `https://localhost:443` (ou `https://<IP_DE_LA_MACHINE>`)
- Identifiants par défaut : `admin` / `SecretPassword`

**⚠️ Change ce mot de passe immédiatement après la première connexion.**

## Dépannage

### `sudo: ./Deploy_docker.sh: command not found`

Ce message ne signifie pas un problème de droits (ce serait `Permission denied`), mais que le fichier n'existe pas à l'endroit ou sous le nom attendu. Vérifie :

```bash
ls -la ./*.sh          # le fichier existe-t-il vraiment ici, avec la bonne casse ?
pwd                     # es-tu dans le bon répertoire ?
file deploy_wazuh.sh    # confirme le type de fichier
```

Linux est sensible à la casse : `Deploy_docker.sh` ≠ `deploy_wazuh.sh` ≠ `deploy_docker.sh`.

### Le conteneur `wazuh.indexer` redémarre en boucle

Presque toujours dû à `vm.max_map_count` trop bas. Vérifie manuellement :

```bash
sysctl vm.max_map_count
sudo sysctl -w vm.max_map_count=262144
```

Pour rendre ce réglage permanent (survit à un reboot) :

```bash
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

### Erreurs liées aux certificats

Si tu changes de version (`TAG`) après un premier déploiement, régénère les certificats pour éviter les incompatibilités :

```bash
cd wazuh-docker/single-node
docker compose down
rm -rf config/wazuh_indexer_ssl_certs/*
docker compose -f generate-indexer-certs.yml run --rm generator
docker compose up -d
```

### Voir les logs en direct

```bash
cd wazuh-docker/single-node
docker compose logs -f
```

## Passer en multi-node (haute disponibilité)

Le multi-node déploie 2 managers, 3 indexers et un reverse-proxy Nginx. Pour l'utiliser, modifie la variable `DEPLOY_MODE` dans le script :

```bash
DEPLOY_MODE="multi-node"
```

La structure des commandes (certificats, `up -d`) reste identique ; seul le répertoire change.
