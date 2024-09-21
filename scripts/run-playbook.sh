#!/usr/bin/env bash
set -o errtrace
trap 'echo "error occurred on line $LINENO ";usage;exit 1' ERR

PLAYBOOK_PATH=""
INVENTORY_PATH=""
KEYPATH=""
LIMIT="all"
USER=""
VERBOSITY=0

usage() {
  echo
  if [ -n "$1" ]; then echo -e "\033[0;31mERROR! $1\033[0m"; echo; fi
  echo "This script executes ansible-playbook with the specified playbook."; echo
  echo "Usage:"; echo
  echo "  bash ./scripts/$(basename "${BASH_SOURCE[0]}") -b ping.yml"; echo
  echo "  bash ./scripts/$(basename "${BASH_SOURCE[0]}") -b ping.yml -u ansible -k ~/.ssh/ansible.key"; echo
  echo "Available options and arguments:"; echo
  echo "  -b, --playbook <value>   Path to a playbook file."; echo
  echo "  -h, --help               Prints this help and exits."; echo
  echo "  -i, --inventory <value>  Path to inventory file with target servers."; echo
  echo "  -k, --key <value>        Path to ssh key to authenticate at target servers."; echo
  echo "  -l, --limit <value>      Limit to group or name of a specific target server."; echo
  echo "  -u, --user <value>       Username to authenticate at target servers."; echo
  echo "  -v, --verbosity <value>  Single-digit integer number that sets ansible verbosity, 0 by default"; echo
  if [ -n "$1" ]; then exit 1; else exit 0; fi
}

parse_input(){
  if [ "$#" -eq 0 ]; then usage "No option or argument provided"; fi

  # parse params
  while [[ "$#" -gt 0 ]]; do case $1 in
      -h|--help) usage; ;;
      -b|--playbook) PLAYBOOK_PATH=$2; shift; shift;;
      -i|--inventory) INVENTORY_PATH=$2; shift; shift;;
      -u|--user) USER=$2; shift; shift;;
      -k|--key) KEYPATH=$2; shift; shift;;
      -l|--limit) LIMIT=$2; shift; shift;;
      -v|--verbosity) VERBOSITY=$2; shift; shift;;
      *) usage "Unknown parameter passed: $1"; ;;
  esac; done
}

parse_input "$@"

if [[ ! -f "${PLAYBOOK_PATH}" ]]; then
  usage "No playbook found by the path \"${PLAYBOOK_PATH}\". Ensure it exists."
fi

if [[ ! -f "${INVENTORY_PATH}" ]]; then
  usage "No inventory found by the path \"${INVENTORY_PATH}\". Ensure it exists."
fi

if [[ -z ${USER} ]]; then
  read -p "User: " -r USER
  if [[ -z ${USER} ]]; then usage "User must be specified"; fi
fi

if [[ ! ${VERBOSITY} =~ ^[0-9]$ ]]; then usage "Verbosity should be single-digit integer"; fi

export ANSIBLE_VERBOSITY=${VERBOSITY}
export ANSIBLE_GATHERING=implicit
export ANSIBLE_SSH_ARGS='-o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no'
export ANSIBLE_HOST_KEY_CHECKING=False

if [[ -z "${KEYPATH}" ]]; then
  ansible-playbook "${PLAYBOOK_PATH}" -i "${INVENTORY_PATH}" -l "${LIMIT}" --timeout=90 -c paramiko -u "${USER}" --ask-pass
elif [[ ! -f "${KEYPATH}" ]]; then
  usage "No key file found with the path ${KEYPATH}. Ensure it exists."
else
  ansible-playbook "${PLAYBOOK_PATH}" -i "${INVENTORY_PATH}" -l "${LIMIT}" --timeout=90 -c paramiko -u "${USER}" --private-key "${KEYPATH}"
fi
