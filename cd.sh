#!/usr/bin/env bash
#
# add 'setup go <args>' to cd to 'setup prefix <args>'

_cd_project_env() {

  if cd "${@}"; then
    source_project_env
  fi
}

alias cd='_cd_project_env'
