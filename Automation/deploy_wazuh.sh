#!/usr/bin/env bash
#
# deploy_wazuh.sh
# Clone le depot officiel wazuh-docker et deploie la stack Wazuh
# (manager + indexer + dashboard) en mode single-node via Docker Compose.
#
# Usage:
#   ./deploy_wazuh.sh [TAG] [INSTALL_DIR]
#
# Exemples:
#   ./deploy_wazuh.sh                     # utilise le tag par defaut, installe dans ./wazuh-docker
#   ./deploy_wazuh.sh v4.14.6             # force une version precise
#   ./deploy_wazuh.sh v4.14.6 /opt/wazuh  # + repertoire d'installation personnalise
#
# Prerequis: git, docker, docker compose (plugin) ou docker-compose (v1)

set -euo pipefail

# ------------------------- Configuration -----------------------------------
REPO_URL="https://github.com/wazuh/wazuh-docker.git"
TAG="${1:-v4.14.6}"                       # tag/branche a cloner (voir `git tag -l` dans le repo pour la liste)
INSTALL_DIR="${2:-$(pwd)/wazuh-docker}"   # ou cloner le depot
DEPLOY_MODE="single-node"                 # single-node | multi-node

log()  { printf '\033[1;32m[+] %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$1"; }
err()  { printf '\033[1;31m[x] %s\033[0m\n' "$1" >&2; }

# ------------------------- Verification des prerequis -----------------------
check_dependencies() {
  log "Verification des prerequis..."

  command -v git >/dev/null 2>&1 || { err "git n'est pas installe."; exit 1; }
  command -v docker >/dev/null 2>&1 || { err "docker n'est pas installe."; exit 1; }

  if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE="docker-compose"
  else
    err "Ni 'docker compose' ni 'docker-compose' n'ont ete trouves."
    exit 1
  fi

  if ! docker info >/dev/null 2>&1; then
    err "Le daemon Docker n'est pas accessible (droits insuffisants ou service arrete ?)."
    exit 1
  fi

  log "Prerequis OK (compose = ${COMPOSE})."
}

# ------------------------- Reglage systeme (OpenSearch) ---------------------
tune_system() {
  # Le Wazuh Indexer (base sur OpenSearch) exige une valeur elevee de
  # vm.max_map_count, sinon le conteneur indexer echoue au demarrage.
  log "Ajustement de vm.max_map_count (requis par le Wazuh Indexer)..."

  current=$(sysctl -n vm.max_map_count 2>/dev/null || echo 0)
  if [ "${current}" -lt 262144 ]; then
    if [ "$(id -u)" -eq 0 ]; then
      sysctl -w vm.max_map_count=262144
    else
      warn "Droits root necessaires pour sysctl. Tentative via sudo..."
      sudo sysctl -w vm.max_map_count=262144
    fi
  else
    log "vm.max_map_count deja suffisant (${current})."
  fi
}

# ------------------------- Clonage du depot ---------------------------------
clone_repo() {
  if [ -d "${INSTALL_DIR}/.git" ]; then
    warn "Le depot existe deja dans ${INSTALL_DIR}, on saute le clone."
  else
    log "Clonage de wazuh-docker (tag: ${TAG}) dans ${INSTALL_DIR}..."
    git clone --branch "${TAG}" --single-branch "${REPO_URL}" "${INSTALL_DIR}"
  fi
}

# ------------------------- Generation des certificats ------------------------
generate_certs() {
  cd "${INSTALL_DIR}/${DEPLOY_MODE}"

  if [ -d "config/wazuh_indexer_ssl_certs" ] && [ "$(ls -A config/wazuh_indexer_ssl_certs 2>/dev/null)" ]; then
    warn "Des certificats existent deja, generation ignoree."
    return
  fi

  log "Generation des certificats SSL (indexer/manager/dashboard)..."
  ${COMPOSE} -f generate-indexer-certs.yml run --rm generator
}

# ------------------------- Lancement des conteneurs ---------------------------
start_containers() {
  cd "${INSTALL_DIR}/${DEPLOY_MODE}"
  log "Demarrage de la stack Wazuh (manager + indexer + dashboard)..."
  ${COMPOSE} up -d

  log "Attente du demarrage complet (l'indexer peut prendre ~1 min)..."
  sleep 15
  ${COMPOSE} ps
}

# ------------------------- Verification finale --------------------------------
verify_deployment() {
  log "Verification de l'etat des conteneurs..."
  cd "${INSTALL_DIR}/${DEPLOY_MODE}"
  ${COMPOSE} ps

  echo
  log "Deploiement termine."
  echo "  Dashboard : https://localhost:443 (ou https://<IP_HOTE>)"
  echo "  Identifiants par defaut : admin / SecretPassword (a changer immediatement)"
  echo "  Logs      : ${COMPOSE} -f ${INSTALL_DIR}/${DEPLOY_MODE}/docker-compose.yml logs -f"
}

# ------------------------------- Main ------------------------------------------
main() {
  check_dependencies
  tune_system
  clone_repo
  generate_certs
  start_containers
  verify_deployment
}

main "$@"
