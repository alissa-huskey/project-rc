#!/usr/bin/env bash
#

source_project_env() {
  local envfile

  envfile="./.project-env"

  if [[ -f "${envfile}" ]] && grep -qx '# allow source' "${envfile}"; then
    source "${envfile}"
  fi
}

