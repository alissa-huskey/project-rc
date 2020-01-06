#!/bin/bash
# shellcheck disable=SC2039
#
# project-rc.sh -- per-project envfiles
#

RC_FILENAMES=( .projectrc .project-env .project .env )

project:find_up() {
  (
    while true; do
      if [[ $PWD == / ]] || [[ $PWD == // ]]; then
        return 1
      fi

      for f in "${@}"; do
        if [[ -f $PWD/$f ]]; then
          echo "$PWD/$f"
          return 0
        fi
      done

      cd ..
    done
  )
}

project:myshell() {
  ps -ocomm= -p $$
}

project:valof() {
  local v shell

  shell="$(project:myshell)"

  if [[ "$shell" =~ bash ]]; then
    v="${!1}"

  elif [[ "$shell" =~ zsh ]]; then
    v="${(P)1}"
  fi

  printf "%s" "$v"
}

project:export() {
  local varname="${1}" old_varname="OLD_${1}" oldval newval="${2}"

  oldval="$(project:valof ${varname})"

  export ${old_varname}="${oldval}"
  export ${varname}="${newval}"
}

project:revert() {
  local varname="${1}" old_varname="OLD_${1}"

  export ${varname}="$(project:valof "${old_varname}")"
  unset "${old_varname}"
}

project:env:source() {
  local envfile="${1}" PROJECT_ROOT="${1%/*}" confirm authfile
  authfile="${HOME}/.projectrc-auth"

  if declare -f on_exit > /dev/null; then
    on_exit
    unset -f on_exit
  fi

  if declare -f on_enter > /dev/null; then
    unset -f on_enter
  fi

  if [[ -f "${envfile}" ]]; then
    if test -f "${authfile}" && \
      gpg --quiet --decrypt "${authfile}" | grep -xq "${PROJECT_ROOT}"; then
      confirm=y
    else
      printf "sourcing file: %s ; ok? " "${envfile}"
      read -r confirm
      echo
    fi

    if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
      source "${envfile}"
      {
        gpg --quiet --decrypt "${authfile}" 2> /dev/null
        echo "${PROJECT_ROOT}"
      } | gpg --quiet --yes --default-recipient-self --armor --encrypt --output "${authfile}"
    else
      echo "Not sourcing."
    fi
  fi

  if declare -f on_enter > /dev/null; then
    on_enter "${envfile%/*}"
  fi
}

project:env:load() {
  envfile="$(project:find_up "${RC_FILENAMES[@]}")"
  if [[ "${envfile}" != "${PROJECT_ENVFILE}" ]]; then
    export PROJECT_ENVFILE="${envfile}"
    export PROJECT_ROOT="${envfile%/*}"

    project:env:source "${envfile}"
  fi
}

project:env:cd() {
  local envfile

  if cd "${@}"; then
    project:env:load
  fi
}

alias cd='project:env:cd'
