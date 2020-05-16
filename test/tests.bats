#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

p() {
  echo "# ${@}" >&3
}

mk_authfile() {
  {
    echo "${PROJECTS_DIR}/vim/recipes/.env"
    echo "${PROJECTS_DIR}/vim/vimpack/.env"
  } | gpg --quiet --yes --default-recipient-self --armor --encrypt --output "${authfile}"
}

setup() {
  source ${BATS_TEST_DIRNAME}/../project-rc.sh
  export PROJECTS_DIR="${BATS_TEST_DIRNAME}/fixtures/projects" DEBUG=
  export authfile="${BATS_TEST_DIRNAME}/fixtures/authfile"
  mk_authfile
}

@test "project:env:load <envfile>" {
  project:env:load "${PROJECTS_DIR}/vim/recipes/.env" <<< "y"

  assert_equal "${PROJECT_ROOT}" "${PROJECTS_DIR}/vim/recipes"
  assert_equal "${PROJECT_NAME}" "recipes"
  assert_equal "${OLD_PROJECT_NAME}" ""
}

@test "project:env:load <envfile> -- successively" {
  export PROJECT_NAME="xxx"

  project:env:load "${PROJECTS_DIR}/vim/recipes/.env" <<< "y"

  assert_equal "${PROJECT_ROOT}" "${PROJECTS_DIR}/vim/recipes"
  assert_equal "${PROJECT_NAME}" "recipes"
  assert_equal "${OLD_PROJECT_NAME}" "xxx"

  project:env:load "${PROJECTS_DIR}/vim/vimpack/.env" <<< "y"

  assert_equal "${PROJECT_ROOT}" "${PROJECTS_DIR}/vim/vimpack"
  assert_equal "${PROJECT_NAME}" "vimpack"

  # this is "xxx" instead of "recipes" because we first revert, then export
  assert_equal "${OLD_PROJECT_NAME}" "xxx"
}

@test "project:auth <envfile> -- when not authed" {
  project:auth "${PROJECTS_DIR}/.tmp"

  run project:is_authed "${PROJECTS_DIR}/.tmp"
  assert_success

  project:deauth "${PROJECTS_DIR}/.tmp"
}

@test "project:auth <envfile> -- when authed" {
  project:auth "${PROJECTS_DIR}/vim/vimpack/.env"

  run project:is_authed "${PROJECTS_DIR}/vim/vimpack/.env"
  assert_success
}

@test "project:deauth <envfile> -- when not authed" {
  project:deauth "${PROJECTS_DIR}/.tmp"

  run project:is_authed "${PROJECTS_DIR}/.tmp"
  assert_failure
}

@test "project:deauth <envfile> -- when authed" {
  project:auth "${PROJECTS_DIR}/.tmp"
  project:deauth "${PROJECTS_DIR}/.tmp"

  run project:is_authed "${PROJECTS_DIR}/.tmp"
  assert_failure
}

@test "project:is_authed <envfile> -- when not authed" {
  run project:is_authed "${PROJECTS_DIR}/.nofile"

  assert_failure
}

@test "project:is_authed <envfile> -- when authed" {
  run project:is_authed "${PROJECTS_DIR}/vim/recipes/.env"

  assert_success
}

@test "project:export <varname> <value> -- no previous value set" {
  project:export THING "something"

  assert_equal "${THING}" "something"
  assert_equal "${OLD_THING}" ""
}

@test "project:export <varname> <value> -- with previous value set" {
  export THING="nothing"

  project:export THING "something"

  assert_equal "${THING}" "something"
  assert_equal "${OLD_THING}" "nothing"
}

@test "project:revert <varname> -- with previous value set" {
  export THING="something" OLD_THING="nothing"

  project:revert THING

  assert_equal "${THING}" "nothing"
  assert_equal "${OLD_THING}" "something"
}

@test "project:revert <varname> -- no previous value set" {
  project:revert THING

  assert_equal "${THING}" ""
  assert_equal "${OLD_THING}" ""
}

@test "project:find_up <filename> -- where PWD is subdir of PROJECT_ROOT" {
  export PWD="$PROJECTS_DIR/toothless/notes"

  run project:find_up ".env"

  assert_success
  assert_output "$PROJECTS_DIR/toothless/.env"
}

@test "project:find_up <filename> -- where PWD is PROJECT_ROOT" {
  export PWD="$PROJECTS_DIR/toothless"

  run project:find_up ".env"

  assert_success
  assert_output "$PROJECTS_DIR/toothless/.env"
}

@test "project:find_up <filename> -- where PWD not in a PROJECT_ROOT" {
  export PWD="$PROJECTS_DIR/archive"

  run project:find_up ".env"

  assert_failure
  assert_output ""
}

@test "project:find_up <filename> -- where PWD is in nested PROJECT_ROOT" {
  export PWD="$PROJECTS_DIR/arduino/wrapper/v2/bin"
  run project:find_up ".env"

  assert_success
  assert_output "$PROJECTS_DIR/arduino/wrapper/v2/.env"

  export PWD="$PROJECTS_DIR/arduino/wrapper/bin"
  run project:find_up ".env"

  assert_success
  assert_output "$PROJECTS_DIR/arduino/wrapper/.env"
}
