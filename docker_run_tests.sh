#!/bin/bash
NGS_MSTB_DOCKER_DIR=$(pwd)
NGS_MSTB_DEPLOY_ROOT=$(cd .. && pwd)

. "$NGS_MSTB_DOCKER_DIR"/docker_common.sh

export EXPORT_TEST_DATA="$NGS_MSTB_DEPLOY_ROOT/ngs-mstb-test-data"
export SEQSTORE_DIR="$EXPORT_TEST_DATA"
export EXPORT_DIR="$NGS_MSTB_DEPLOY_ROOT/../ngs_mstb_gal_export"
export EXPORT_LOGS_DIR="$EXPORT_DIR/logs"

mkdir -p "$EXPORT_DIR"
mkdir -p "$EXPORT_LOGS_DIR"
#    -v ${EXPORT_DIR}:/export \
#    -v ${SEQSTORE_DIR}:/seqstore/data \
# -d
#    -p 80:80 \
#    -p 443:443 \

docker run --rm --name ngs-mstb \
    -v ${EXPORT_TEST_DATA}:/home/galaxy/work/test_data \
    ${NGS_MSTB_DOCKER_IMAGE}:${NGS_MSTB_DOCKER_TAG:-latest} \
    ngs_mstb_test_run.sh
