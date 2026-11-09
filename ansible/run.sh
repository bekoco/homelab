#!/usr/bin/env bash
# Lance le playbook depuis WSL.
# Les options sont passees en variables d'environnement car Ansible ignore
# un ansible.cfg situe dans un dossier Windows (/mnt/c) monte en ecriture pour tous.
set -euo pipefail
cd "$(dirname "$0")"

export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_STDOUT_CALLBACK=default
export ANSIBLE_CALLBACK_RESULT_FORMAT=yaml
export ANSIBLE_RETRY_FILES_ENABLED=False

ansible-playbook -i inventory.ini site.yml "$@"
