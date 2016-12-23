#!/bin/bash
set -euo pipefail

# accepts: BUILD_NUMBER DATA_DIR [URL PLAYBOOK | URL]
build=$1
data=$2
url=${3-}

# provide simple defaulting of playbooks
playbook="${4:-playbooks/provision.yaml}"
if [[ -z "${3-}" && -z "${4-}" ]]; then
  playbook="playbooks/deprovision.yaml"
fi

# configure the startup script to use the provided repository URL for binaries
startup="$( mktemp -d )/startup.sh"
cat << STARTUP > "${startup}"
#!/bin/bash
set -euo pipefail

cat << EOF > /etc/yum.repos.d/origin-override.repo
[origin-override]
baseurl = "${url}"
gpgcheck = 0
name = OpenShift Origin Release
enabled = 1
EOF
STARTUP

# start a container with the custom playbook inside it
docker rm gce-pr &>/dev/null || true
docker create --name gce-pr openshift/origin-gce:latest ansible-gce -e "pull_identifier=pr${build}" "${playbook}" >/dev/null
docker cp "${data}" gce-pr:/usr/local/install
docker cp "${startup}" gce-pr:/usr/local/install/data/
rm "${startup}"
docker start -a gce-pr