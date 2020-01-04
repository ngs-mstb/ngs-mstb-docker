#ARG GAL_TAG=latest #not supported on RHEL 7.5 Docker
FROM docker.io/bgruening/galaxy-stable:19.05
ADD build_data_files/build_no_pkgs.tar.gz /
ADD build_data_files/micgent_db /build/micgent_db
RUN mkdir -p /seqstore/data
ADD build_data_files/test_data /seqstore/test_data
ADD build_data_files/example_out.tar.gz ${GALAXY_ROOT}/static/

ARG GALAXY_UID_NEW
ARG GALAXY_GID_NEW
ARG TOOL_CONF_BASE=tool_conf_no_radar.xml

ENV GALAXY_UID_OLD=${GALAXY_UID}
ENV GALAXY_GID_OLD=${GALAXY_GID}

ENV GALAXY_UID=${GALAXY_UID_NEW:-$GALAXY_UID}
ENV GALAXY_GID=${GALAXY_GID_NEW:-$GALAXY_GID}

### MAIN RUN-TIME PARAMERTERS ###
ENV NONUSE=condor
ENV GALAXY_CONFIG_SMTP_SERVER=localhost
ENV GALAXY_CONFIG_ERROR_EMAIL_TO=ngs_mstb@ngs-mstb.nowhere
ENV GALAXY_CONFIG_ADMIN_USERS=admin_ge@ngs-mstb.nowhere
ENV GALAXY_DEFAULT_ADMIN_USER=admin_ge
ENV GALAXY_DEFAULT_ADMIN_EMAIL=admin_ge@ngs-mstb.nowhere
ENV GALAXY_CONFIG_BRAND=NGS-MSTB
ENV GALAXY_CONFIG_REQUIRE_LOGIN=False
ENV GALAXY_CONFIG_SHOW_WELCOME_WITH_LOGIN=True
ENV GALAXY_CONFIG_NEW_USER_DATASET_ACCESS_ROLE_DEFAULT_PRIVATE=True
ENV GALAXY_CONFIG_ALLOW_USER_CREATION=True
## Use HTTPS protocol
ENV USE_HTTPS=False
## Set to True for DEV instance only to debug tool errors
ENV GALAXY_CONFIG_ALLOW_USER_IMPERSONATION=False

## You should **OVERRIDE** these at run-time for anything but
## isolated testing runs!!! Keeping defaults can expose your
## Galaxy instance to remote control!!!
ENV GALAXY_CONFIG_MASTER_API_KEY=1b61i877676f76a7c01d13fa
ENV GALAXY_DEFAULT_ADMIN_PASSWORD=NgsMstb20
ENV GALAXY_DEFAULT_ADMIN_KEY=375wfjgwe256r56dfyfd0ca
## Secret server key to generate signatures that prevent
## modifications of intermediate datasets - override.
ENV NGS_MSTB_SIG_KEY=4rgeg10gergebftei7458ca
ENV NGS_MSTB_GALAXY_REPORTS_PASSWORD=betwe48g4gel0642d1a037
## END OF **OVERRIDE** section
### END OF MAIN RUN-TIME PARAMERTERS ###

WORKDIR ${GALAXY_ROOT}

ADD ngs_mstb_docker_build.sh /usr/bin/
ADD ngs-mstb/galaxy/scripts/galaxy_delete_accounts.py /usr/bin/

ARG PRELOAD_GALAXY_CONDITIONAL_DEPENDENCIES=1
RUN /usr/bin/ngs_mstb_docker_build.sh "${GALAXY_UID}" "${GALAXY_GID}"

ENV NGS_MSTB_ROOT=/ngs-mstb
ENV NGS_MSTB_GALAXY_CONFIGS=$NGS_MSTB_ROOT/galaxy/config NGS_MSTB_TOOL_DIR=$NGS_MSTB_ROOT/galaxy/tools/ngs_mstb

ENV GALAXY_CONFIG_DEPENDENCY_RESOLVERS_CONFIG_FILE=${NGS_MSTB_GALAXY_CONFIGS}/dependency_resolvers_conf.xml
ENV GALAXY_CONFIG_TOOL_CONFIG_FILE=${NGS_MSTB_GALAXY_CONFIGS}/${TOOL_CONF_BASE}
ENV GALAXY_CONFIG_DATATYPES_CONFIG_FILE=config/datatypes_conf.xml.sample,${NGS_MSTB_TOOL_DIR}/datatypes_conf.xml
ENV GALAXY_CONFIG_AUTH_CONFIG_FILE=${NGS_MSTB_GALAXY_CONFIGS}/auth_conf.xml

## this is already set to False in base container, but just in case.
## TODO: code editing of whitelist file and set this to True
ENV GALAXY_CONFIG_SANITIZE_ALL_HTML=False

ENV GALAXY_LOGGING=full
ENV GALAXY_CONFIG_ALLOW_USER_DATASET_PURGE=True
ENV GALAXY_DESTINATIONS_DEFAULT=local_no_container
ENV GALAXY_RUNNERS_ENABLE_CONDOR=False
ENV GALAXY_RUNNERS_ENABLE_SLURM=True
ENV GALAXY_CONFIG_ENABLE_QUOTAS=False
ENV GALAXY_CONFIG_SESSION_DURATION=0

ADD ngs-mstb $NGS_MSTB_ROOT
## A trick to copy `radar_cli_secrets` directory only if it exists
ADD dummy_sentinel.txt build_data_files/radar_cli_secret[s] $NGS_MSTB_TOOL_DIR/

#RUN git apply $NGS_MSTB_ROOT/galaxy/patches/*.patch

RUN chown galaxy. ${GALAXY_LOGS_DIR}
RUN chown galaxy. ${NGS_MSTB_ROOT}

ENV NGS_MSTB_GALAXY_REPORTS_USER=ngs_mstb_reports
ENV NGS_MSTB_GALAXY_REPORTS_PASSWORD=ngs_mstb_reports

ADD ngs_mstb_startup.sh /usr/bin/
ADD ngs_mstb_test_run.sh /usr/bin/

## Note that /export is already declared a VOLUME by base image,
## so any copy into /export here would be a NOOP
## There is also some /data volume in base (see `docker inspect image_id`)
ADD ngs-mstb/galaxy/static static/
## This will only be picked up if it goes to /etc/galaxy/web:
RUN cp static/welcome* $(dirname "$GALAXY_CONFIG_WELCOME_URL")
ADD ngs-mstb/galaxy/lib/galaxy/auth/providers/ldap_plus_filter_script.py lib/galaxy/auth/providers/
ADD ngs-mstb/galaxy/tools/ngs_mstb/static/images static/images/

ADD ngs-mstb/galaxy/tools/ngs_mstb/tours/* config/plugins/tours/


CMD ["/usr/bin/ngs_mstb_startup.sh"]

ENV NGS_MSTB_TEST_WORK=$GALAXY_HOME/work
ADD build_data_files/micgent $NGS_MSTB_TEST_WORK/micgent
ADD build_data_files/micgent/python/lib/MICGENT /build/mc3/envs/ngs-mstb/lib/python3.6/site-packages/MICGENT/
RUN mkdir -p $NGS_MSTB_TEST_WORK/micgent/python/test_run
RUN chown -R galaxy. $NGS_MSTB_TEST_WORK

RUN mkdir -p $NGS_MSTB_TEST_WORK/micgent/python/test_run
VOLUME $NGS_MSTB_TEST_WORK/micgent/python/test_run