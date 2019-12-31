#!/usr/bin/env bash
set -ex -o pipefail

## replace a simple key: value entry in a line-formatted YAML file or
## a key=value assignment in a shell file.
## pass before/after ansible replace module parameter through optional other_args if
## you need to replace only some entries of the identical keys in different sections
simple_key_replace() {
  local sep="$1"
  shift
  local sep_sfx="$1"
  shift
  local path="$1"
  shift
  local key=$1
  shift
  local value="$1"
  shift
  local other_args="$1"
  ansible localhost -m replace \
    -a "path='$path' regexp='^(\\s*${key}${sep})[^\\n]*$' replace='\\1${sep_sfx}${value}' $other_args"
}

yaml_simple_key_replace() {
  simple_key_replace ":" " " "$@"
}

shell_simple_key_replace() {
  simple_key_replace "=" "" "$@"
}

if [[ -z "$NGS_MSTB_TOOL_DIR" || ! -e "$NGS_MSTB_TOOL_DIR" ]];
then
  echo "Variable NGS_MSTB_TOOL_DIR='$NGS_MSTB_TOOL_DIR' must be defined and point to an existing directory"
  exit 1
fi

[ -n "$NGS_MSTB_SIG_KEY" ] && yaml_simple_key_replace "$NGS_MSTB_TOOL_DIR/secrets.yaml" key "$NGS_MSTB_SIG_KEY"
[ -n "$GALAXY_CONFIG_MASTER_API_KEY" ] && yaml_simple_key_replace "$NGS_MSTB_TOOL_DIR/secrets.yaml" api_key "$GALAXY_CONFIG_MASTER_API_KEY"
if [ -n "$NGS_MSTB_RADAR_JAR" ];
then
  radar_jar="$NGS_MSTB_TOOL_DIR/$NGS_MSTB_RADAR_JAR"
  yaml_simple_key_replace "$NGS_MSTB_TOOL_DIR/ngs_mstb.yaml" jar "$radar_jar"
  shell_simple_key_replace "$NGS_MSTB_TOOL_DIR/ldap_filter_script.sh" jar "$radar_jar"
fi
if [ -n "$NGS_MSTB_RADAR_RMI" ];
then
  yaml_simple_key_replace "$NGS_MSTB_TOOL_DIR/ngs_mstb.yaml" rmi_registry "$NGS_MSTB_RADAR_RMI"
  shell_simple_key_replace "$NGS_MSTB_TOOL_DIR/ldap_filter_script.sh" rmi_registry "$NGS_MSTB_RADAR_RMI"
fi

gal_hostname=$(hostname --fqdn)
if [[ "x$USE_HTTPS" == "xTrue" ]]; then
  gal_prot="https"
  ansible localhost -m lineinfile -a "path='/etc/nginx/sites-enabled/default' backrefs=yes regexp='^(\\s*server_name localhost;)\\s*\$' line='\\1 return 301 https://\$server_name\$request_uri;'"
else
  gal_prot="http"
fi
yaml_simple_key_replace "$NGS_MSTB_TOOL_DIR/secrets.yaml" url "${gal_prot}://${gal_hostname}"

if [ -f "$EXPORT_DIR/auth_conf.xml" ]; then
  ansible localhost -m copy -a "src='$EXPORT_DIR/auth_conf.xml' dest='$GALAXY_CONFIG_AUTH_CONFIG_FILE' owner=galaxy group=galaxy mode=0400"
fi

if [ -n "$NGS_MSTB_GALAXY_REPORTS_PASSWORD" ];
then
  REPORTS_PASSWORD_FILE=/export/reports_htpasswd
  touch "$REPORTS_PASSWORD_FILE"
  chmod go-rwx "$REPORTS_PASSWORD_FILE"
  echo -n "$NGS_MSTB_GALAXY_REPORTS_USER:" > "$REPORTS_PASSWORD_FILE"
  echo "$NGS_MSTB_GALAXY_REPORTS_PASSWORD" | openssl passwd -apr1 -stdin >> "$REPORTS_PASSWORD_FILE"
  ## Upstream Asinbles provision runs from startup and wipes out our changes
  ## Brute-forcing it here:
  cp /etc/nginx/conf.d/reports_auth.conf.source /etc/nginx/conf.d/reports_auth.conf
  cp -a "$REPORTS_PASSWORD_FILE" /etc/nginx/htpasswd
  ## the password will get broken if it has j2 template combinations like {%%}
  cp -a "$REPORTS_PASSWORD_FILE" /ansible/roles/galaxyprojectdotorg.galaxyextras/templates/htpasswd.j2
  cp /ansible/roles/galaxyprojectdotorg.galaxyextras/templates/nginx_reports_auth.conf.j2 /ansible/roles/galaxyprojectdotorg.galaxyextras/templates/nginx_reports_noauth.conf.j2
fi

chown galaxy.galaxy /home/galaxy/logs
exec /usr/bin/startup "$@"
