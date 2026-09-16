#!/bin/bash

ROOT=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

[ $# -eq 0 ] && {
  ./do --tasks
  exit 0
}

if [ "$1" == "clobber" ]; then
  "${ROOT}/bin/clobber"
  exit $?
elif [ "$1" == "clean" ]; then
  "${ROOT}/bin/clean"
  exit $?
fi

# Load local toolchain preference if present (gitignored, user-specific).
# Create .toolchain-local with: UDB_TOOLCHAIN_CONTAINER=1  (or 0 for native)
[ -f "${ROOT}/.toolchain-local" ] && source "${ROOT}/.toolchain-local"

# Start mise with a compact, predictable environment.  Some shell integrations
# export enough metadata to exceed execve's combined argv/environment limit.
exec env -i \
  HOME="$HOME" \
  USER="${USER:-$(id -un)}" \
  LOGNAME="${LOGNAME:-${USER:-$(id -un)}}" \
  TERM="${TERM:-dumb}" \
  PATH="/usr/local/bin:/usr/bin:/bin" \
  UDB_TOOLCHAIN_CONTAINER="${UDB_TOOLCHAIN_CONTAINER:-}" \
  "${ROOT}/bin/mise" exec --cd "${ROOT}" -- bundle exec --gemfile "${ROOT}/Gemfile" ruby -r rake -e "Rake.application.init('do');Rake.application.load_rakefile;Rake.application.top_level" -- "$@"
