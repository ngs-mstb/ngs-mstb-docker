#!/bin/bash
username="$1"
#CLI of the SOR. The JAR is supposed to be signed and tied to the client and server hosts.
jar=/some/path/RadarImport.jar
rmi_registry=http://some.url/RegistryLocation.xml
#this_dir=$(cd $(dirname "$0") && pwd)
#galaxy_root=$(cd "$this_dir"/../.. && pwd)
#tool_dir="$galaxy_root/tools/ngs_mstb"
## If using Python, we need to cleanup after Galaxy virtualenv, or either Conda init fails, or PYTHONPATH gets in the way
#export VIRTUAL_ENV=
#export PYTHONPATH=
#source "$galaxy_root/database/dependencies/ngs-mstb/1.0/env.sh"
#python -m MICGENT.gene_extractor --config "$tool_dir/ngs_mstb.yaml" radar-check-user "$username"
## Or simply run Java by the full path
/build/mc3/envs/ngs-mstb/bin/java -jar "$jar" -v "$rmi_registry" "$username"
