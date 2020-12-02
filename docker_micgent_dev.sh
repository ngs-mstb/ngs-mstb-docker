#!/bin/bash
NGS_MSTB_DOCKER_DIR=$(pwd)
NGS_MSTB_DEPLOY_ROOT=$(cd .. && pwd)

. "$NGS_MSTB_DOCKER_DIR"/docker_common.sh

export EXPORT_TEST_DATA="$NGS_MSTB_DEPLOY_ROOT/ngs-mstb-test-data"
export EXPORT_TEST_RUN="$NGS_MSTB_DEPLOY_ROOT/../ngs_mstb_test_run"

## The working dir gets so large that we almost always run out of space
## on the Docker host partition. Therefore, we create this bind mount.
## You need to make sure that the host dir is on a file system with about
## 400GB of free space.

mkdir -p "$EXPORT_TEST_RUN"

docker run -it --rm --name ngs-mstb \
    -v "$NGS_MSTB_DEPLOY_ROOT"/micgent/:/home/galaxy/work/micgent/ \
    -v "$NGS_MSTB_DOCKER_DIR"/ngs_mstb_test_run.sh:/usr/bin/ngs_mstb_test_run.sh \
    -v ${EXPORT_TEST_DATA}:/home/galaxy/work/test_data \
    -v ${EXPORT_TEST_RUN}:/home/galaxy/work/micgent/python/test_run \
    -e NGS_MSTB_TEST_MODE=DEV \
    -e NGS_MSTB_TEST_SLURM=NO \
    ${NGS_MSTB_DOCKER_IMAGE}:${NGS_MSTB_DOCKER_TAG:-latest} \
    bash /usr/bin/ngs_mstb_test_run.sh

