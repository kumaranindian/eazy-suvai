#!/usr/bin/env bash
# Shared helpers for the ops scripts (M13). Every script:
#   - takes the project id as its first argument;
#   - only prints the commands unless --apply is given (dry run by default);
#   - refuses the production project unless CONFIRM_PROD=yes is set.
set -euo pipefail

PROD_PROJECT="eazysuvai-prod"
APPLY=false

parse_common() {
  PROJECT="${1:-}"
  if [[ -z "$PROJECT" || "$PROJECT" == --* ]]; then
    echo "Usage: $0 <project-id> [--apply]" >&2
    exit 2
  fi
  shift
  for a in "$@"; do
    [[ "$a" == "--apply" ]] && APPLY=true
  done
  if [[ "$PROJECT" == "$PROD_PROJECT" && "$APPLY" == true && "${CONFIRM_PROD:-}" != "yes" ]]; then
    echo "Refusing to change $PROD_PROJECT without CONFIRM_PROD=yes." >&2
    exit 2
  fi
  echo "# project: $PROJECT  mode: $([[ $APPLY == true ]] && echo APPLY || echo 'dry run (add --apply)')"
}

# run <command...>: prints it; runs it with --apply.
run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  if [[ "$APPLY" == true ]]; then "$@"; fi
}
