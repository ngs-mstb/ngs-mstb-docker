#!/bin/bash
## Developer's script.
## Use this script to edit MICGENT code on the host and test the changes 
## inside the NGS-MSTB running container without rebuilds and restarts.
## You can also run Galaxy jobs this way with the current MICGENT code from the host.
## For Galaxy to run and for larger tests from MICGENT testing harness, set
## envvar NGS_MSTB_TEST_SLURM=YES. It is NO by default because it icreases the
## container startup time by about one minute.
## Execute this script when the PWD is the directory containing the script.
## To work correctly, this script expects some code and testing data to be
## located in defined places outside of this directory. See the variables
## dereferenced below for the specifics.

NGS_MSTB_DOCKER_DIR=$(pwd)
NGS_MSTB_DEPLOY_ROOT_DEF=$(cd .. && pwd)
NGS_MSTB_DEPLOY_ROOT=${NGS_MSTB_DEPLOY_ROOT:-"$NGS_MSTB_DEPLOY_ROOT_DEF"}

. "$NGS_MSTB_DOCKER_DIR"/docker_common.sh

export EXPORT_TEST_DATA="$NGS_MSTB_DEPLOY_ROOT/ngs-mstb-test-data"
export EXPORT_TEST_RUN="$NGS_MSTB_DEPLOY_ROOT/../ngs_mstb_test_run"

NGS_MSTB_DEFAULT_DOCKER_OPT=${NGS_MSTB_DEFAULT_DOCKER_OPT:-"-p 8080:80"}

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
    -e NGS_MSTB_TEST_MODE=${NGS_MSTB_TEST_MODE:-DEV} \
    -e NGS_MSTB_TEST_SLURM=${NGS_MSTB_TEST_SLURM:-NO} \
    -e GALAXY_CONFIG_SINGLE_USER=admin_ge@ngs-mstb.nowhere \
    ${NGS_MSTB_DEFAULT_DOCKER_OPT} \
    ${NGS_MSTB_DOCKER_IMAGE}:${NGS_MSTB_DOCKER_TAG:-latest} \
    bash /usr/bin/ngs_mstb_test_run.sh

