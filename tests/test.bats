#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # Override this variable for your add-on:
  export GITHUB_REPO=your-org/ddev-claude-sandbox

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-claude-sandbox"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/${PROJNAME}.XXXXXX")"
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

health_checks() {
  # Verify basic DDEV functionality
  run ddev describe
  assert_success
  assert_output --partial "${PROJNAME}"
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  # Persist TESTDIR if running inside GitHub Actions
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

@test "claude command is available" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  # Claude should be available
  run ddev claude --version
  assert_success
  assert_output --partial "Claude Code"
}

@test "agent-env command works" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  # agent-env should execute commands
  run ddev agent-env echo "test"
  assert_success
  assert_output --partial "test"
}

@test "setup script creates hook files" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  # Check that hook files are created in ~/.claude/hooks/
  run ddev exec bash -c 'test -f ~/.claude/hooks/url-allowlist-check.sh'
  assert_success

  run ddev exec bash -c 'test -f ~/.claude/hooks/url-allowlist-add.sh'
  assert_success

  run ddev exec bash -c 'test -f ~/.claude/hooks/env-protection.sh'
  assert_success
}

@test "settings.json is generated with hooks" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  # Check that settings.json exists and contains hook configuration
  run ddev exec bash -c 'test -f ~/.claude/settings.json'
  assert_success

  run ddev exec bash -c 'cat ~/.claude/settings.json'
  assert_success
  assert_output --partial "PreToolUse"
  assert_output --partial "url-allowlist-check.sh"
  assert_output --partial "env-protection.sh"
}

@test "url allowlist can be disabled" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success

  # Disable URL allowlist by modifying the addon config directly
  sed -i.bak 's/CLAUDE_URL_ALLOWLIST_ENABLED=true/CLAUDE_URL_ALLOWLIST_ENABLED=false/' .ddev/config.claude-sandbox.yaml

  run ddev restart -y
  assert_success

  # settings.json should not contain URL allowlist hooks or WebFetch matcher
  run ddev exec bash -c 'cat ~/.claude/settings.json'
  assert_success
  refute_output --partial "url-allowlist-check.sh"
  refute_output --partial "url-allowlist-add.sh"
  refute_output --partial "WebFetch"
  # PostToolUse should be empty (only used for URL allowlist)
  assert_output --partial '"PostToolUse": []'
}

@test "env protection can be disabled" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success

  # Disable env protection by modifying the addon config directly
  sed -i.bak 's/CLAUDE_ENV_PROTECTION_ENABLED=true/CLAUDE_ENV_PROTECTION_ENABLED=false/' .ddev/config.claude-sandbox.yaml

  run ddev restart -y
  assert_success

  # settings.json should not contain env protection hooks
  run ddev exec bash -c 'cat ~/.claude/settings.json'
  assert_success
  refute_output --partial "env-protection.sh"
}

@test "claude config directory exists" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  # Check ~/.claude directory exists
  run ddev exec bash -c 'test -d ~/.claude'
  assert_success
}

@test "credentials are persisted and symlinked" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  # Seed credentials file in ~/.claude, then restart to trigger move + symlink
  run ddev exec bash -c 'mkdir -p ~/.claude && printf "token=abc123\n" > ~/.claude/.credentials.json'
  assert_success

  run ddev restart -y
  assert_success

  # Check symlink points to persisted file in project volume
  run ddev exec bash -c 'test -L ~/.claude/.credentials.json'
  assert_success
  run ddev exec bash -c 'readlink -f ~/.claude/.credentials.json'
  assert_success
  assert_output --partial "/var/www/html/.ddev/claude/credentials.json"

  # Check content persisted
  run ddev exec bash -c 'cat /var/www/html/.ddev/claude/credentials.json'
  assert_success
  assert_output --partial "token=abc123"
}
# bats file_tags=a
@test "claude config is persisted and symlinked" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  # Seed claude config file in ~, then restart to trigger move + symlink
  run ddev exec bash -c 'printf "{\"version\":1}\n" > ~/.claude.json'
  assert_success

  run ddev restart -y
  assert_success

  # Check symlink points to persisted file in project volume
  run ddev exec bash -c 'test -L ~/.claude.json'
  assert_success
  run ddev exec bash -c 'readlink -f ~/.claude.json'
  assert_success
  assert_output --partial "/var/www/html/.ddev/claude/claude.json"

  # Check content persisted
  run ddev exec bash -c 'cat /var/www/html/.ddev/claude/claude.json'
  assert_success
  assert_output --partial "\"version\":1"
}
# bats file_tags=

@test "protected files pattern is configurable" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success

  # Set custom protected files by modifying the addon config directly
  sed -i.bak 's/CLAUDE_PROTECTED_FILES=.env.local,.env.\*.local/CLAUDE_PROTECTED_FILES=.secrets,credentials.json/' .ddev/config.claude-sandbox.yaml

  run ddev restart -y
  assert_success

  # Check env-protection.sh contains the custom pattern
  run ddev exec bash -c 'cat ~/.claude/hooks/env-protection.sh'
  assert_success
  assert_output --partial ".secrets"
  assert_output --partial "credentials.json"
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}
