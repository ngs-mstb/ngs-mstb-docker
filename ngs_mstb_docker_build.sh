#!/usr/bin/env bash
set -ex -o pipefail
GALAXY_UID_NEW=$1
shift
GALAXY_GID_NEW=$1
shift
GALAXY_UID=${GALAXY_UID_NEW:-$GALAXY_UID}
GALAXY_GID=${GALAXY_GID_NEW:-$GALAXY_GID}

## From upstream docker-compose: Fix the multiple ID addresses issue cause by swarm
#echo "NETWORK_INTERFACE = $$(hostname -i | cut --delimiter " " --fields 2)" >> /etc/condor/config.d/fix-network

## For local tools that should run as singleton instances (such as external resource-constrained),
## we edit job_conf.xml file here. We create a dynamic destination that simply routes to
## the default destination as defined by the envar; create a limits section for that
## destination; and create a tool section that assigns the tool to the limited destination.

## Note: the resulting file would look nicer if we inserted a newline before the matched closing tag,
## but that turns off the automatic Ansible idempotency for some reason. Maybe the `replace` module could
## do better?
ansible localhost -m lineinfile -a "path='$GALAXY_CONFIG_JOB_CONFIG_FILE' backrefs=yes \
regexp='(</destinations>)' \
line='<destination id=\"limit_concurrent\" \
runner=\"dynamic\"> \
<param id=\"type\">choose_one</param> \
<param id=\"destination_ids\" from_environ=\"GALAXY_DESTINATIONS_DEFAULT\">slurm_cluster</param> \
</destination> \\1'"

ansible localhost -m lineinfile -a "path='$GALAXY_CONFIG_JOB_CONFIG_FILE' backrefs=yes \
regexp='(</limits>)' \
line='<limit type=\"destination_total_concurrent_jobs\" id=\"limit_concurrent\">1</limit> \\1'"

ansible localhost -m lineinfile -a "path='$GALAXY_CONFIG_JOB_CONFIG_FILE' backrefs=yes \
regexp='(</job_conf>)' \
line='<tools><tool id=\"radar_upload\" destination=\"limit_concurrent\"/></tools> \\1'"

## On InternalException from DRMAA, retry that many times, and if still failing, return datasets
## in the error state instead of green empty state as per default. This fights Slurm time-outs
## that happen when multiple jobs are running concurrently.
## These settings propagate into `lib/runners/drmaa.py`
ansible localhost -m lineinfile -a "path='$GALAXY_CONFIG_JOB_CONFIG_FILE' backrefs=yes \
regexp='(.*<plugin.*SlurmJobRunner.>)' \
line='\\1 <param id=\"internalexception_retries\">30</param> <param id=\"internalexception_state\">error</param>'"

## Toil also suffers from Slurm timeouts. Increase the key parameter in the Python
## config generator deployed by the base image. That script is called from base
## startup script that gets called from our startup and then blocks for the life of the
## container.
ansible localhost -m lineinfile -a "path='/usr/sbin/configure_slurm.py' \
insertafter='\\s*#*SlurmdTimeout=[0-9]+$' \
regexp='\\s*#*MessageTimeout=[0-9]*'
line='MessageTimeout=40'"


## for account deletion below
service postgresql start

##  Do things that require working in Galaxy virtualenv
. $GALAXY_VIRTUAL_ENV/bin/activate

# Preload of dependencies at build time. Such as LDAP used by a custom auth module.
# Preloading here is needed for two reasons:
# - Galaxy lib function that builds a list of conditional dependencies has a hard-wired
#   function that decides if python-ldap is needed based on authenticator name in auth_conf:
#   https://docs.galaxyproject.org/en/release_18.05/_modules/galaxy/dependencies.html
#   So if the auth module uses ldap but is called itself
#   not ldap, it never gets istalled by LOAD_GALAXY_CONDITIONAL_DEPENDENCIES at startup
# - Installing modules at startup introduces dependency on external Galaxy wheel repo at run-time
#
# Adapted from galaxyproject/galaxy/scripts/common_startup.sh
if [[ "x$PRELOAD_GALAXY_CONDITIONAL_DEPENDENCIES" != "x" ]]
    then
        echo "Installing known-to-be-used optional Galaxy dependencies in galaxy virtual environment..."
        : ${GALAXY_WHEELS_INDEX_URL:="https://wheels.galaxyproject.org/simple"}
        GALAXY_CONDITIONAL_DEPENDENCIES="python-ldap"
        [ -z "$GALAXY_CONDITIONAL_DEPENDENCIES" ] || echo "$GALAXY_CONDITIONAL_DEPENDENCIES" | pip install -q -r /dev/stdin --index-url "${GALAXY_WHEELS_INDEX_URL}"
fi

echo "Checking if database is up and running"
until /usr/local/bin/check_database.py 2>&1 >/dev/null; do sleep 1; echo "Waiting for database"; done
echo "Database connected"

touch scripts/__init__.py
PYTHONPATH=.:$PYTHONPATH python /usr/bin/galaxy_delete_accounts.py -c /etc/galaxy/galaxy.yml all

deactivate
##  Done doing things that require working in Galaxy virtualenv

## If necessary, redefine galaxy OS account. This is adapted from
## Galaxy ansible startup template that is not activated by the upstream
## docker build by default. Typically this is done in order to match
## the host account ID to ensure proper access to files mounted from
## the host.
old_uid=`stat -c '%u' "$GALAXY_HOME"`
old_gid=`stat -c '%g' "$GALAXY_HOME"`
old_perms="$old_uid:$old_gid"

source_uid=$GALAXY_UID
source_gid=$GALAXY_GID
source_perms="$source_uid:$source_gid"

if [[ ("x$GALAXY_UID" != "x" || "x$GALAXY_GID" != "x") && "x$old_perms" != "x$source_perms" ]];
then
  deluser $GALAXY_USER
  groupadd -r $GALAXY_USER -g $source_gid
  useradd -u $source_uid -r -g $GALAXY_USER -d "$GALAXY_HOME" -c "Galaxy User" $GALAXY_USER -s /bin/bash
  echo $GALAXY_USER:$GALAXY_USER | chpasswd

  for target_path in /opt /home /tmp/slurm \
    /galaxy_venv /tool_deps /shed_tools /galaxy-central;
  do
    if [ -e "$target_path" ];
    then
      chown -R --from=$old_perms galaxy.galaxy $target_path
    fi
  done
fi
