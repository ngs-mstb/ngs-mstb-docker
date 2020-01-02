#!/bin/bash
set -ex
## set TOOL_CONF_BASE=tool_conf.xml if you want upload_to_radar too to appear in Galaxy
## the tool will not work if radar_secrets jar is not baked into container as well as
## RADAR settings provided in ngs-mstb-secrets and in custom auth script
#GALAXY_UID_NEW=23514
#GALAXY_GID_NEW=561

. docker_common.sh

mkdir -p build_data_files/test_data/rsv
cp -a ../ngs-mstb-test-data/micgent_large_test_data/rsv/INF2019_CTR build_data_files/test_data/rsv/

docker build \
--tag ${NGS_MSTB_DOCKER_IMAGE}:${NGS_MSTB_DOCKER_TAG} \
--build-arg GALAXY_UID_NEW=$GALAXY_UID_NEW \
--build-arg TOOL_CONF_BASE=tool_conf_no_radar.xml \
--build-arg GALAXY_GID_NEW=$GALAXY_GID_NEW .

docker tag ${NGS_MSTB_DOCKER_IMAGE}:${NGS_MSTB_DOCKER_TAG} ${NGS_MSTB_DOCKER_IMAGE}:latest

