#!/usr/bin/env bash
set -ex -o pipefail

## This script will execute unittests.
## You need to to start the container with
## $NGS_MSTB_TEST_WORK/test_data containing
## micgent_large_test_data and micgent_db

## We need to have Slurm service ON. It gets 
## configured on every container start by
## the base image startup script that blocks once it
## launches Galaxy, so we need
## to run that script first in a detached mode
## and spin-wait for Slurm

function check_slurmd {
  ps -el | grep -q slurmctld
}

# Waits until Slurm is ready; squeue tries for 60 sec
function wait_for_slurm {
  echo "Checking if Slurm is up and running"
  until squeue 2>&1 >/dev/null; do sleep 1; echo "Waiting for Slurm"; done
  echo "Slurm is up"
}

if ! check_slurmd; then
  nohup /usr/bin/ngs_mstb_startup.sh 2>&1 >/dev/null &
  wait_for_slurm
fi

## do not use -i here - this causes Galaxy's internal Conda to be used in tests
sudo -u galaxy bash << EOF
cd $NGS_MSTB_TEST_WORK/micgent/python

. /build/mc3/etc/profile.d/conda.sh
conda activate ngs-mstb
../scripts/ngs-mstb/run_tests_gene_extractor.sh  $NGS_MSTB_TEST_WORK/test_data  \
  2>&1 | tee test_run/test_out.log
EOF
