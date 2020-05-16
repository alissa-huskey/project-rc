#!/usr/bin/env bash

# project-rc.sh -- per-project envfiles
# https://github.com/alissa-huskey/project-rc
#

RC_FILENAMES=( .projectrc .project-env .project .env )

project:color() {
  if ! command -v sfx > /dev/null; then
    return
  fi

  if [[ "$1" == "off" ]]; then
    sfx off
    return
  fi

  sfx set "$@"
}

project:debug() {
  if [[ -z $DEBUG ]]; then
    return
  fi

  printf "$(project:color cyan)project> $(project:color yellow)[DEBUG]$(project:color off) %s\n" "${*}" >&2
}

# usage: project:find_up <filename> [...<filename>]
#   walk up the directory tree until any <filename>
#   is found, then print it
#   if not found, return 1
project:find_up() {
  local pwd="${PWD}"
  project:debug "project:find_up() PWD: '${pwd}'"

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

# usage: project:export <varname> <value>
#   save the current value of <varname> to OLD_<varname>
#   set <varname> to <value> then export it
project:export() {
  local varname="${1}" old_varname="OLD_${1}" newval="${2}" curval oldval

  project:debug "project:export() $1 $2"

  curval=$(eval "echo \"\$${varname}\"")
  oldval=$(eval "echo \"\$${old_varname}\"")

  project:debug "project:export() BEFORE value of $varname: '$curval'"
  project:debug "project:export() BEFORE value of $old_varname: '$oldval'"

  eval "${old_varname}=\"${curval}\""
  eval "${varname}=\"${newval}\""

  export ${old_varname}="${curval}"
  export ${varname}="${newval}"

  curval=$(eval "echo \"\$${varname}\"")
  oldval=$(eval "echo \"\$${old_varname}\"")
  project:debug "project:export() AFTER value of $varname: '$curval'"
  project:debug "project:export() AFTER value of $old_varname: '$oldval'"
}

# usage: project:revert <varname>
#   set <varname> to the value of OLD_<varname> then export it
project:revert() {
  local varname="${1}" old_varname="OLD_${1}" oldval

  curval=$(eval "echo \"\$${varname}\"")
  oldval=$(eval "echo \"\$${old_varname}\"")
  
  project:debug "project:revert() BEFORE value of $varname: '$curval'"
  project:debug "project:revert() BEFORE value of $old_varname: '$oldval'"

  export ${varname}="${oldval}"
  export ${old_varname}="${curval}"

  curval=$(eval "echo \"\$${varname}\"")
  oldval=$(eval "echo \"\$${old_varname}\"")

  project:debug "project:revert() AFTER value of $varname: '$curval'"
  project:debug "project:revert() AFTER value of $old_varname: '$oldval'"
}

# usage: project:is_authed <envfile>
#   returns true if <envfile> is authorized
project:is_authed() {
  test -s "${authfile}" && gpg --quiet --decrypt "${authfile}" | grep -xq "${1}"
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
# usage: deauth <envfile>
#    deauthorize <envfile>
project:deauth() {
  if ! project:is_authed "${1}"; then
    return
  fi

    gpg --quiet --decrypt "${authfile}" 2> /dev/null   \
      | sed "\:${1}: d"                                \
      | gpg --quiet --yes --default-recipient-self --armor --encrypt --output "${authfile}"
}

# project:env:exit
#   unset PROJECT_ROOT and PROJECT_ENVFILE and call on_exit()
project:env:exit() {
  # run the defined on_exit function from previously loaded envfile
  # then clear on_exit and on_enter
  if declare -f on_exit > /dev/null; then
    project:debug "${PROJECT_ENVFILE}:on_exit()"
    on_exit
    unset -f on_exit
  fi

  if declare -f on_enter > /dev/null; then
    unset -f on_enter
  fi

  unset PROJECT_ROOT PROJECT_ENVFILE
  typeset +x PROJECT_ROOT PROJECT_ENVFILE
}

# project:env:enter <envfile>
#   set PROJECT_ROOT and PROJECT_ENVFILE and call on_enter()
project:env:enter() {
  local envfile="${1}" project_root="${1%/*}"
  project:debug "project:env:enter()"

  if [[ ! -s "${envfile}" ]] || [[ -z "${envfile}" ]]; then
    project:debug "missing or empty envfile"
    return
  fi

  if ! project:is_authed "${envfile}"; then
    project:debug "project not authed"
    return
  fi

  export PROJECT_ROOT="${project_root}"
  export PROJECT_ENVFILE="${envfile}"

  if declare -f on_enter > /dev/null; then
    project:debug "${PROJECT_ENVFILE}:on_enter()"
    on_enter
  fi
}

# project:env:source <envfile>
#   authorize and source <envfile>
project:env:source() {
  local envfile="${1}" confirm

  project:debug "project:env:source() ${envfile}"

  # exit early without an envfile
  if [[ ! -s "${envfile}" ]] || [[ -z "${envfile}" ]]; then
    project:debug "missing or empty envfile"
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

  # auth and source envfile
  if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then

    project:auth "${envfile}"
    source "${envfile}"

  # or refuse to authrozie
  else
    echo "Refusing to source."
  fi
}

project:init() {
  authfile="${HOME}/.projectrc-auth"
}

# usage: project:env:init
#   run in the current directory to search for a project envfile,
#   set relevant env variables and source if authed
project:env:init() {
  local envfile authfile

  project:debug "project:env:init()"

  project:init

  envfile="$(project:find_up "${RC_FILENAMES[@]}")"

  if [[ "${envfile}" != "$PROJECT_ENVFILE" ]]; then
    project:env:load "${envfile}"
  fi

}

# project:env:load <envfile>
#   on_exit from the previous env, source the new one and on_enter the new one
project:env:load() {
  project:debug "Prev PROJECT_ROOT: $PROJECT_ROOT"

  project:env:exit
  project:env:source "${1}"
  project:env:enter "${1}"

  project:debug "New PROJECT_ROOT: $PROJECT_ROOT"
}

# usage: project:env:cd
#   for aliasing cd to
project:env:cd() {
  project:debug cd "${@}"

  if \cd "${@}"; then
    project:env:init
  fi
}

alias cd='project:env:cd'
