#!/bin/bash
## Pass required parameters through these environment variables:
## NGS_MSTB_DEPLOY_CONFIG_DIR - points to checked out `ngs-mstb-secrets` repository
## NGS_MSTB_HOSTNAME - hostname matching subdirectory NGS_MSTB_DEPLOY_CONFIG_DIR/hosts
set -ex -o pipefail
[ -n "$NGS_MSTB_DEPLOY_CONFIG_DIR" ] || exit 1
export NGS_MSTB_DEPLOY_CONFIG_DIR=$(cd "$NGS_MSTB_DEPLOY_CONFIG_DIR" && pwd)

[ -n "$NGS_MSTB_HOSTNAME" ] || exit 1

set -o allexport
. "$NGS_MSTB_DEPLOY_CONFIG_DIR/shell.env"
set +o allexport
export NGS_MSTB_SITE_CONFIG_DIR="$NGS_MSTB_DEPLOY_CONFIG_DIR/hosts/$NGS_MSTB_HOSTNAME"

[ -n "$EXPORT_DIR" ] || exit 1
[ -n "$EXPORT_LOGS_DIR" ] || exit 1

mkdir -p "$EXPORT_DIR"
mkdir -p "$EXPORT_LOGS_DIR"

[ -d "$NGS_MSTB_SITE_CONFIG_DIR" ] || exit 1
[ -d "$EXPORT_DIR" ] || exit 1
[ -d "$EXPORT_LOGS_DIR" ] || exit 1

[ -f "${NGS_MSTB_SITE_CONFIG_DIR}/server.key" ] && install --mode 600 "${NGS_MSTB_SITE_CONFIG_DIR}/server.key" "$EXPORT_DIR/server.key"
[ -f "${NGS_MSTB_SITE_CONFIG_DIR}/server.crt" ] && install --mode 600 "${NGS_MSTB_SITE_CONFIG_DIR}/server.crt" "$EXPORT_DIR/server.crt"

for f in "$NGS_MSTB_DEPLOY_CONFIG_DIR"/welcome*; do
    [ -e "$f" ] && cp "$f" "$EXPORT_DIR/"
done

if [ -f "${NGS_MSTB_SITE_CONFIG_DIR}/auth_conf.xml" ]; then
    install --mode 600 "${NGS_MSTB_SITE_CONFIG_DIR}/auth_conf.xml" "$EXPORT_DIR/auth_conf.xml"
fi

## try pulling first because for some reason Composer failed to pull from private registry even when user was logged in
docker pull $NGS_MSTB_DOCKER_IMAGE:$NGS_MSTB_DOCKER_TAG || true
docker stack deploy -c docker-compose.yml ngs-mstb
