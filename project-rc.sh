#!/usr/bin/env bash

# project-rc.sh -- per-project envfiles
# https://github.com/alissa-huskey/project-rc

#################################################################
# private functions {{{
#
#   functions internal to project functions

# usage: project:_err <message>
#    print a debug message if DEBUG is set
project:_err() {
  printf "\x1b[31mError\x1b[0m %s\n" "${*}" >&2
}

# usage: project:_debug <message>
#    print a debug message if DEBUG is set
project:_debug() {
  if [[ -z $DEBUG ]]; then
    return
  fi

  printf "\x1b[36m[DEBUG]\x1b[0m %s\n" "${*}" >&2
}

# usage: project:_find_up <filename> [...<filename>]
#   walk up the directory tree until any <filename>
#   is found, then print it
#   if not found, return 1
project:_find_up() {
  local pwd="${PWD}"
  project:_debug "project:_find_up() PWD: '${pwd}'"

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

# usage: project:_is_authed <envfile>
#   returns true if <envfile> is authorized
project:_is_authed() {
  test -s "${RC_AUTHFILE}" && project:_decrypt | grep -xq "${1}"
}

# usage: auth <envfile>
#    authorize <envfile>
project:_auth() {
  if project:_is_authed "${1}"; then
    project:_debug "'${1}' already authorized"
    return
  fi

  {
    project:_decrypt
    echo "${1}"
  } | project:_encrypt
}

# usage: deauth <envfile>
#    deauthorize <envfile>
project:_deauth() {
  if ! project:_is_authed "${1}"; then
    return
  fi

    project:_decrypt       \
      | sed "\:${1}: d"    \
      | project:_encrypt
}

project:_decrypt() {
  gpg --quiet --decrypt "${RC_AUTHFILE}" 2> /dev/null
}

project:_encrypt() {
  if ! gpg --quiet --yes --default-recipient-self --armor --encrypt --output "${RC_AUTHFILE}" ; then
    project:_err "Unable to encrypt authfile: ${RC_AUTHFILE}"
    return 1
  fi
}

# print a command
project:_cmd() {
  printf "\x1b[2m# %s\x1b[0m\n" "${*}"
}

# print a formatted header
project:_header() {
  printf "\n\x1b[1;97m%s\x1b[0m\n\n" "${*}"
}

# one time setup of auth file
project:_setup() {
  [[ -s "${RC_AUTHFILE}" ]] && return

  project:_debug "initalizing authfile: ${RC_AUTHFILE}"

  {
    printf "# project-rc auth file for %s@%s initialized at %s\n" "$(whoami)" "$(hostname)" "$(date)"
    printf "# https://github.com/alissa-huskey/project-rc\n"
  } | project:_encrypt
}

#
# }}} / private functions


#################################################################
# public API {{{
#
#   functions available for usage in .env files
#

RC_FILENAMES=( .env .envrc .project .projectrc .project-env )
: "${RC_AUTHFILE:=${HOME}/.projectrc-auth}"

project() {
  local cmd="$1"

  if [[ -z "$cmd" ]]; then
    cmd="help"
  fi

  case "$cmd" in
    -h|--help|help)  project:help      ;      ;;
    new)             project:new       ;      ;;
  esac
}

project:help() {

printf "usage: project [command]\n"

  project:_header COMMANDS
  cat <<-EOHELP
   new                                    generate a .env file for this project
   help                                   show this usage information
EOHELP

  project:_header FUNCTIONS
  cat <<-EOHELP
   project:export <name> <value>          export <name> to <value> and save old value
   project:revert <name>                  revert <name> to old value
EOHELP

}

project:new() {
  local contents filename=".env"

  if [[ -f "${filename}" ]]; then
    project:_err "${filename} file already exists"
    return 1
  fi

  printf "write to %s? [Yn] " "$filename"
  read -r confirm
  if [[ ! "$confirm" =~ ^[yY]$ ]]; then
    return
  fi

  cat <<EOF > "$envfilename"
#!$SHELL

# project rc file
#
#   valid names: .projectrc .project-env .project .env .envrc
#
#   environment varialbes:
#      PROJECT_ROOT        path to the root dir of your project (where this file is located)
#      PROJECT_ENVFILE     path and filename of this file
#      RC_AUTHFILE         path to file listing authorized envfiles

on_enter() {
  project:export SOMEVAR "someval"
}

on_exit() {
  project:revert SOMEVAR
}
EOF

}

#
# }}} / public API


#################################################################
# public functions {{{
#
#   functions available for usage in .env files
#

# usage: project:export <varname> <value>
#   save the current value of <varname> to OLD_<varname>
#   set <varname> to <value> then export it
project:export() {
  local varname="${1}" old_varname="OLD_${1}" newval="${2}" curval oldval

  project:_debug "project:export() $1 $2"

  curval=$(eval "echo \"\$${varname}\"")
  oldval=$(eval "echo \"\$${old_varname}\"")

  project:_debug "project:export() BEFORE value of $varname: '$curval'"
  project:_debug "project:export() BEFORE value of $old_varname: '$oldval'"

  eval "${old_varname}=\"${curval}\""
  eval "${varname}=\"${newval}\""

  export "${old_varname?}" "${varname?}"

  curval=$(eval "echo \"\$${varname}\"")
  oldval=$(eval "echo \"\$${old_varname}\"")
  project:_debug "project:export() AFTER value of $varname: '$curval'"
  project:_debug "project:export() AFTER value of $old_varname: '$oldval'"
}

# usage: project:revert <varname>
#   set <varname> to the value of OLD_<varname> then export it
project:revert() {
  local varname="${1}" old_varname="OLD_${1}" oldval

  curval=$(eval "echo \"\$${varname}\"")
  oldval=$(eval "echo \"\$${old_varname}\"")

  project:_debug "project:revert() BEFORE value of $varname: '$curval'"
  project:_debug "project:revert() BEFORE value of $old_varname: '$oldval'"

  export ${varname}="${oldval}"
  export ${old_varname}="${curval}"

  curval=$(eval "echo \"\$${varname}\"")
  oldval=$(eval "echo \"\$${old_varname}\"")

  project:_debug "project:revert() AFTER value of $varname: '$curval'"
  project:_debug "project:revert() AFTER value of $old_varname: '$oldval'"
}

#
# }}} / public functions


#################################################################
# project:env {{{
#
#   functions that are called to change the environment
#

# project:env:exit
#   unset PROJECT_ROOT and PROJECT_ENVFILE and call on_exit()
project:env:exit() {
  # run the defined on_exit function from previously loaded envfile
  # then clear on_exit and on_enter
  if declare -f on_exit > /dev/null; then
    project:_debug "${PROJECT_ENVFILE}:on_exit()"
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
  project:_debug "project:env:enter()"

  if [[ -z "${envfile}" ]]; then
    project:_debug "no env file found, moving on."
    return
  fi

  if [[ ! -s "${envfile}" ]]; then
    project:_debug "empty envfile"
    return
  fi

  if ! project:_is_authed "${envfile}"; then
    project:_debug "project not authed"
    return
  fi

  export PROJECT_ROOT="${project_root}"
  export PROJECT_ENVFILE="${envfile}"

  if declare -f on_enter > /dev/null; then
    project:_debug "${PROJECT_ENVFILE}:on_enter()"
    on_enter
  fi
}

# project:env:source <envfile>
#   authorize and source <envfile>
project:env:source() {
  local envfile="${1}" confirm

  project:_debug "project:env:source() ${envfile}"

  # exit early without an envfile
  if [[ ! -s "${envfile}" ]] || [[ -z "${envfile}" ]]; then
    project:_err "missing or empty envfile"
    return
  fi

  # check if the envfile is authed
  if project:_is_authed "${envfile}"; then
    confirm=y

  # or prompt to auth
  else
    printf 'source file: "%s" [yN] ' "${envfile}"
    read -r confirm
    echo
  fi

  # auth and source envfile
  if [[ "$confirm" =~ ^[yY]$ ]]; then

    if project:_auth "${envfile}"; then
      source "${envfile}"
    else
      project:_err "Unable to authorize ${envfile}"
      return 1
    fi

  # or refuse to authrozie
  else
    project:_err "Refusing to source."

  fi
}

# usage: project:env:init
#   run in the current directory to search for a project envfile,
#   and load it if found
project:env:init() {
  local envfile

  project:_debug "project:env:init()"
  envfile="$(project:_find_up "${RC_FILENAMES[@]}")"

  if [[ "${envfile}" != "$PROJECT_ENVFILE" ]]; then
    project:_debug "loading: '${envfile}'"
    project:env:load "${envfile}"
  fi

}

# usage: project:env:load <envfile>
#   load <envfile>
#   call old on_exit(), source <envfile>, call new on_enter()
project:env:load() {

  project:_debug "Prev PROJECT_ROOT: '$PROJECT_ROOT'"
  project:env:exit

  if project:env:source "${1}"; then
    project:env:enter "${1}"
    project:_debug "New PROJECT_ROOT: '$PROJECT_ROOT'"
  else
    project:_err "Failed to source: ${PROJECT_ROOT}"
  fi
}

# usage: project:env:cd
#   for aliasing cd to
project:env:cd() {
  project:_debug cd "${@}"

  if \cd "${@}"; then
    project:_debug "PWD '${PWD}'"
    project:_debug "RC_AUTHFILE: '${RC_AUTHFILE}'"

    project:env:init
  fi
}

project:_setup
