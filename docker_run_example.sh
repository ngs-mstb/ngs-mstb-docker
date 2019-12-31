#!/bin/bash
NGS_MSTB_DOCKER_DIR=$(pwd)
NGS_MSTB_DEPLOY_ROOT=$(cd .. && pwd)

. "$NGS_MSTB_DOCKER_DIR"/docker_common.sh

# -d
#    -p 80:80 \
#    -p 443:443 \

docker run --rm -d -p 8080:80 --name ngs-mstb -e GALAXY_CONFIG_SINGLE_USER=admin_ge@ngs-mstb.nowhere ${NGS_MSTB_DOCKER_IMAGE}:${NGS_MSTB_DOCKER_TAG:-latest}
