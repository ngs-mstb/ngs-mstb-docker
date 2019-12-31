#!/bin/bash
build_context=../ngs-mstb-test-data
docker_file=Dockerfile.micgent_test_data
[ -f $docker_file ] || exit 1
[ -d $build_context ] || exit 1
cp $docker_file $build_context/
docker build  --tag ngs-mstb-test-data:1.6 -f $build_context/$docker_file $build_context
