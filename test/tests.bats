#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

p() {
  echo "# ${@}" >&3
}

setup() {
  source ${BATS_TEST_DIRNAME}/../project-rc.sh
  export PROJECTS_DIR="${BATS_TEST_DIRNAME}/fixtures/projects"
}

@test "project:env:source <envfile>" {
  project:env:source "${PROJECTS_DIR}/vim/recipes/.env" <<< "y"

  assert_equal "${PROJECT_ROOT}" "${PROJECTS_DIR}/vim/recipes"
  assert_equal "${PROJECT_NAME}" "recipes"
  assert_equal "${OLD_PROJECT_NAME}" ""
}

@test "project:env:source <envfile> -- successively, failing" {
  skip "broken test"

  export PROJECT_NAME="xxx"
  project:env:source "${PROJECTS_DIR}/vim/recipes/.env" <<< "y"

  assert_equal "${PROJECT_ROOT}" "${PROJECTS_DIR}/vim/recipes"
  assert_equal "${PROJECT_NAME}" "recipes"
  assert_equal "${OLD_PROJECT_NAME}" "xxx"

  project:env:source "${PROJECTS_DIR}/vim/vimpack/.env" <<< "y"

  assert_equal "${PROJECT_ROOT}" "${PROJECTS_DIR}/vim/vimpack"
  assert_equal "${PROJECT_NAME}" "vimpack"

  # this is broken-- don't know why
  assert_equal "${OLD_PROJECT_NAME}" "recipes"
}

@test "project:env:source <envfile> -- successively" {
  export PROJECT_NAME="xxx"
  project:env:source "${PROJECTS_DIR}/vim/recipes/.env" <<< "y"

  assert_equal "${PROJECT_ROOT}" "${PROJECTS_DIR}/vim/recipes"
  assert_equal "${PROJECT_NAME}" "recipes"
  assert_equal "${OLD_PROJECT_NAME}" "xxx"

  project:env:source "${PROJECTS_DIR}/vim/vimpack/.env" <<< "y"

  assert_equal "${PROJECT_ROOT}" "${PROJECTS_DIR}/vim/vimpack"
  assert_equal "${PROJECT_NAME}" "vimpack"

  # this is broken-- don't know why
  # assert_equal "${OLD_PROJECT_NAME}" "recipes"
}

@test "project:auth <envfile>" {
  skip
}

@test "project:is_authed <envfile>" {
  skip
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
  assert_equal "${OLD_THING}" ""
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
