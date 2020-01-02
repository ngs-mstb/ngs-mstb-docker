#!/bin/bash
set -ex

. docker_common.sh

mkdir -p build_data_files/empty

docker build \
-f Dockerfile.micgent_builder \
--tag ${NGS_MSTB_DOCKER_DEPS_IMAGE}:${NGS_MSTB_DOCKER_TAG} \
build_data_files/empty

