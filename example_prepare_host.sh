#!/bin/bash
## Example sequence of commands to prepare the production host OS for deployment of
## the NGS-MSTB container.
## Execute commands from this file one-by-one,
## adapting if necessary to a specific OS flavor.
## Follow the additional instructions provided in the comments throughout this file.
## This file is not meant to be executed in batch mode.
##
## Before you execute the commands from this file, ensure that:
##  - The host OS version is RHEL or CentOS 7.5 or higher
##  - Docker is installed and works, including the Docker Composer
##  - Docker directories are on a file system with at least 80GB
##    of free space.
##  - Docker is configured so that you can use `docker login` and `docker
##    pull` from the private repository
##  - User `galaxy` with primary group `galaxy` exists, with
##    UID=23514 and GID=561 (or the IDs that you baked into your image if you
##    built a custom one). If another user name or group name exists
##    with the same UID/GID, delete the duplicate entity.
##  - The input sequence repository is mounted at /seqstore, and
##    the user `galaxy` can read from it.
##  - There is a writable file system /data with at least 1TB of free space.
##  - Git is installed
##  - If interfacing with the SOR, then the installer's (you - a person executing this script)
##    is enabled in SOR ACLs (this is only needed for "smoke test" at the end).
##  - The installer has access to `ngs-mstb-secrets` Git repository and can clone it locally.
##  - You have accessto clone other repositories comprising NGS-MSTB system
##

##
## **Run the following commands as root**
##

adduser galaxydepl
passwd galaxydepl
usermod -aG docker galaxydepl
mkdir /data/ngs-mstb
chown galaxydepl. /data/ngs-mstb
mkdir /data/ngs-mstb-deploy
chown galaxydepl. /data/ngs-mstb-deploy

## switching to galaxydepl account
su - galaxydepl

## **Run the following commands as galaxydepl**

cd /data/ngs-mstb-deploy
## If necessary:
## Temporarily deploy the private SSH key into `~galaxydepl/.ssh/` in order
## to clone the respective Git repositories used below. Set its access permissions
## to 600.

## Edit the NGS_MSTB_DOCKER_GIT_TAG below as instructed by developers
NGS_MSTB_DOCKER_GIT_TAG=2.5
git clone --branch=$NGS_MSTB_DOCKER_GIT_TAG https://github.com/ngs-mstb/ngs-mstb-docker.git

## Edit the NGS_MSTB_SECRETS_GIT_TAG below and the YOU-OWN-ORG part or the entire URL
NGS_MSTB_SECRETS_GIT_TAG=2.2
git clone --branch=$NGS_MSTB_SECRETS_GIT_TAG git@github.com:YOUR-OWN-ORG/ngs-mstb-secrets.git

cd ngs-mstb-docker

export NGS_MSTB_DEPLOY_CONFIG_DIR=../ngs-mstb-secrets

## Edit the NGS_MSTB_HOSTNAME below as appropriate for the deployment target.
## It should match the name of a subdirectory under `$NGS_MSTB_DEPLOY_CONFIG_DIR/hosts`.
## It should be either an FQDN hostname or CNAME of the host where you are running it.
export NGS_MSTB_HOSTNAME=localhost

## This uses Docker Swarm to execute docker-compose.yaml. Adjust if you are using
## a different container management framework.
## Check if this node is already a member of a Docker swarm, and is a leader
docker node ls
## If the command printed something like:
##
## ID                           HOSTNAME                        STATUS  AVAILABILITY  MANAGER STATUS
## <SOME ID> *  <CURRENT HOSTNAME>  Ready   Active        Leader
##
## then proceed to the docker_deploy.sh command below. Otherwise, if the node is part of a swarm but
## is not a leader, use `docker swarm leave` to leave the swarm.
## Start new swarm as a leader:
## Run ifconfig and record the IP address of the host network interface (such as eth0),
## the assign that IP address to environment variable SWARM_INIT_ADVERTIZE_ADDR
ifconfig
## Initialize the swarm
docker swarm init --advertise-addr $SWARM_INIT_ADVERTIZE_ADDR
## End Check if this node is already a member of a Docker swarm, and is a leader

## Login to registry again in case we were logged out for inactivity
## after we checked docker login at the beginning.

## Start the service
./docker_deploy.sh

## The last command should have deployed a Docker service and printed its name.
## Check that the service runs:
docker service ps --no-trunc ngs-mstb_galaxy-web
## The expected output should show STATE column as Running. Repeat the `ps` command
## above a few times if the STATE is something else.

## Once deployed, the service will be maintained by Docker is the running state
## even across OS reboots. The service can be removed with `docker service rm ngs-mstb_galaxy-web`

## From your Chrome browser, open `https://$NGS_MSTB_HOSTNAME`. It might take up to three
## minutes before the server become ready. You can see various "not available" or
## "access denied" errors before the server becomes ready.
## Once the server becomes ready, you should see Galaxy login prompt. Login with
## your LDAP account if you configured that, or with admin_ge or whatever administrator
## account you configured. On success, you should see the Galaxy welcome page
## in the middle, and a list of tools such as NGS Microbial Sequencing Toolbox
## on the left. If you see that, the installation is complete. Leave `/data/ngs-mstb-deploy`
## directory as-is. It will be needed if you have to change startup configuration later on.
## The directory `/data/ngs-mstb` is where the running Galaxy instance will keep its
## state and the temporary job working directories.
