#!/bin/bash
# shellcheck disable=SC2039
#
# project-rc.sh -- per-project envfiles
# https://github.com/alissa-huskey/project-rc
#

RC_FILENAMES=( .projectrc .project-env .project .env )

# usage: project:find_up <filename> [...<filename>]
#   walk up the directory tree until any <filename>
#   is found, then print it
#   if not found, return 1
project:find_up() {
  local pwd="${PWD}"
  while true; do
    if [[ -z "$pwd" ]] || [[ $pwd == / ]] || [[ $pwd == // ]]; then
      return 1
    fi

    for f in "${@}"; do
      if [[ -f $pwd/$f ]]; then
        echo "$pwd/$f"
        return 0
      fi
    done

    pwd="${pwd%/*}"
  done
}

# usage: project:myshell
#   print the current shell
project:myshell() {
  ps -ocomm= -p $$
}

# usage: project:valof <varname>
#   print the value of <varname>
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

# usage: project:export <varname> <value>
#   save the current value of <varname> to OLD_<varname>
#   set <varname> to <value> then export it
project:export() {
  local varname="${1}" old_varname="OLD_${1}" newval="${2}" oldval 

  oldval=$(eval "echo \"\$$varname\"")

  export ${old_varname}="${oldval}"
  export ${varname}="${newval}"
}

# usage: project:revert <varname>
#   set <varname> to the value of OLD_<varname> then export it
project:revert() {
  local varname="${1}" old_varname="OLD_${1}"

  export ${varname}="$(project:valof "${old_varname}")"
  unset "${old_varname}"
}

# usage: project:is_authed <envfile>
#   returns true if <envfile> is authorized
project:is_authed() {
  test -f "${authfile}" && gpg --quiet --decrypt "${authfile}" | grep -xq "${1}"
}

# usage: auth <envfile>
#    authorize <envfile>
project:auth() {
  if project:is_authed "${1}"; then
    return
  fi

  {
    gpg --quiet --decrypt "${authfile}" 2> /dev/null
    echo "${1}"
  } | gpg --quiet --yes --default-recipient-self --armor --encrypt --output "${authfile}"
}

# project:env:source <envfile>
#   run on_exit, source <envfile>, and run on_enter
project:env:source() {
  local envfile="${1}" project_root="${1%/*}" confirm authfile
  authfile="${HOME}/.projectrc-auth"

  # run the defined on_exit function from previously loaded envfile
  # then clear on_exit and on_enter
  if declare -f on_exit > /dev/null; then
    on_exit
    unset -f on_exit
  fi

  if declare -f on_enter > /dev/null; then
    unset -f on_enter
  fi

  # exit early without an envfile
  if [[ ! -f "${envfile}" ]]; then
    return
  fi

  # check if the envfile is authed
  if project:is_authed "${envfile}"; then
    confirm=y

  # or prompt to auth
  else
    printf "sourcing file: %s ; ok? " "${envfile}"
    read -r confirm
    echo
  fi

  # auth and source envfile then run on_enter
  if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
    export PROJECT_ROOT="${project_root}"

    project:auth "${envfile}"
    source "${envfile}"

    if declare -f on_enter > /dev/null; then
      on_enter
    fi

  # or refuse to authrozie
  else
    echo "Refusing to source."
  fi
}

# usage: project:env:load
#   run in the current directory to search for a project envfile,
#   set relevant env variables and source if authed
project:env:load() {
  local envfile
  envfile="$(project:find_up "${RC_FILENAMES[@]}")"
  if [[ "${envfile}" != "${PROJECT_ENVFILE}" ]]; then
    project:env:source "${envfile}"
  fi
}

# usage: project:env:cd
#   for aliasing cd to
project:env:cd() {
  local envfile

  if cd "${@}"; then
    project:env:load
  fi
}

alias cd='project:env:cd'
