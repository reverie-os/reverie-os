#!/usr/bin/env bash
# commit-lint.sh — enforce the Reverie OS commit format (see FORMAT.md).
#
#   Single message:  scripts/commit-lint.sh --repo=meta --msg-file=FILE [--files=FILE]
#   Commit range:    scripts/commit-lint.sh --repo=meta --range='BASE..HEAD'
#
# --repo   meta          → scopes must equal touched split dirs (needs --files/--range)
# --repo   <split name>  → scopes must include that split (verbatim multi-scope OK)
# --files  newline-separated `git diff --name-only` output for the commit
#
# To add a split: append its name to KNOWN_SCOPES below (sorted), to the
# matrix in .github/workflows/split.yml, and to the root flake.nix.
set -euo pipefail

KNOWN_SCOPES="iso nixconf meta"
TYPES="feat fix chore docs refactor test ci build perf style revert"

REPO="meta"
MSG_FILE=""
FILES_FILE=""
RANGE=""

usage() {
  echo "usage: commit-lint.sh --repo=NAME (--msg-file=FILE [--files=FILE] | --range=RANGE)" >&2
  exit 2
}

for arg in "$@"; do
  case "$arg" in
    --repo=*) REPO="${arg#--repo=}" ;;
    --msg-file=*) MSG_FILE="${arg#--msg-file=}" ;;
    --files=*) FILES_FILE="${arg#--files=}" ;;
    --range=*) RANGE="${arg#--range=}" ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $arg" >&2; usage ;;
  esac
done

if ! printf '%s' "$KNOWN_SCOPES" | tr ' ' '\n' | grep -qx "$REPO" && [ "$REPO" != "meta" ]; then
  echo "error: --repo=$REPO is not a known scope ($KNOWN_SCOPES)" >&2
  exit 2
fi

trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

# lint_one MSG_TEXT [FILES_TEXT] — exit nonzero with diagnostics on failure.
lint_one() {
  local msg="$1" files="${2:-}" header type scopes_csv subject
  header="$(printf '%s\n' "$msg" | sed -n '/[^[:space:]]/{p;q;}')"

  # GitHub-generated commits are exempt.
  case "$header" in
    "Merge pull request "*|"Merge branch "*|"Merge remote"*"|Revert\ \""*\")
      echo "  ok (exempt): $header"
      return 0 ;;
  esac

  if ! [[ "$header" =~ ^([a-z]+)\(([A-Za-z0-9_,\ -]+)\):\ (.+)$ ]]; then
    echo "  FAIL: header must be 'type(scope,…): subject' — got: $header" >&2
    return 1
  fi
  type="${BASH_REMATCH[1]}"
  scopes_csv="${BASH_REMATCH[2]}"
  subject="${BASH_REMATCH[3]}"

  if ! printf '%s\n' $TYPES | tr ' ' '\n' | grep -qx "$type"; then
    echo "  FAIL: unknown type '$type' (want one of: $TYPES)" >&2
    return 1
  fi

  # Parse + validate scope list.
  local -a scopes=()
  local s
  IFS=',' read -ra scopes <<< "$scopes_csv"
  for i in "${!scopes[@]}"; do
    s="$(printf '%s' "${scopes[$i]}" | trim)"
    [ -n "$s" ] || { echo "  FAIL: empty scope in '$scopes_csv'" >&2; return 1; }
    [[ "$s" =~ ^[a-z0-9-]+$ ]] || { echo "  FAIL: bad scope '$s' (lowercase, digits, dashes)" >&2; return 1; }
    printf '%s' "$KNOWN_SCOPES" | tr ' ' '\n' | grep -qx "$s" \
      || { echo "  FAIL: unknown scope '$s' (known: $KNOWN_SCOPES)" >&2; return 1; }
    scopes[$i]="$s"
  done
  # No duplicates, sorted.
  if [ "$(printf '%s\n' "${scopes[@]}" | sort -u | wc -l)" != "${#scopes[@]}" ]; then
    echo "  FAIL: duplicate scope in '$scopes_csv'" >&2; return 1
  fi
  if [ "$(printf '%s\n' "${scopes[@]}" | sort | paste -sd, -)" != "$(printf '%s\n' "${scopes[@]}" | paste -sd, -)" ]; then
    echo "  FAIL: scopes must be sorted alphabetically: '$scopes_csv'" >&2; return 1
  fi

  # meta is exclusive: it means "touches no split".
  local has_meta=0
  for s in "${scopes[@]}"; do [ "$s" = "meta" ] && has_meta=1; done
  if [ "$has_meta" = 1 ] && [ "${#scopes[@]}" != 1 ]; then
    echo "  FAIL: 'meta' must be the only scope (it means: touches no split)" >&2
    return 1
  fi

  # Subject shape.
  if [ "${#subject}" -gt 72 ]; then
    echo "  FAIL: subject >72 chars (${#subject})" >&2; return 1
  fi
  if [[ "$subject" =~ \.$ ]]; then
    echo "  FAIL: subject must not end with a period" >&2; return 1
  fi

  # Sections: collect [scope]: lines, each must name a listed scope.
  local -a sections=()
  while IFS= read -r line; do
    if [[ "$line" =~ ^\[([a-z0-9-]+)\]: ]]; then
      sections+=("${BASH_REMATCH[1]}")
    fi
  done <<< "$msg"
  for s in ${sections[@]+"${sections[@]}"}; do
    printf '%s\n' "${scopes[@]}" | grep -qx "$s" \
      || { echo "  FAIL: section [$s]: names a scope not listed in header ($scopes_csv)" >&2; return 1; }
  done
  # Multi split-scope header → every split scope needs its section.
  local n_split=0
  for s in "${scopes[@]}"; do [ "$s" != "meta" ] && n_split=$((n_split + 1)); done
  if [ "$n_split" -gt 1 ]; then
    for s in "${scopes[@]}"; do
      printf '%s\n' ${sections[@]+"${sections[@]}"} | grep -qx "$s" \
        || { echo "  FAIL: multi-scope commit needs a [$s]: section (see FORMAT.md)" >&2; return 1; }
    done
  fi

  # Split-lane rule: message must name its own repo.
  if [ "$REPO" != "meta" ]; then
    printf '%s\n' "${scopes[@]}" | grep -qx "$REPO" \
      || { echo "  FAIL: in $REPO, scopes must include '$REPO' (got: $scopes_csv)" >&2; return 1; }
  fi

  # Meta-lane rule: listed split scopes must equal touched split dirs.
  if [ "$REPO" = "meta" ] && [ -n "$files" ]; then
    local -a touched=()
    local f top known hit
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      top="${f%%/*}"
      if [[ "$f" != */* ]]; then
        continue # root-level file: rides along, forces no scope
      fi
      hit=0
      for known in $KNOWN_SCOPES; do
        if [ "$known" != "meta" ] && [ "$top" = "$known" ]; then hit=1; fi
      done
      [ "$hit" = 1 ] && touched+=("$top")
    done <<< "$files"
    local touched_csv listed_csv
    touched_csv="$(printf '%s\n' ${touched[@]+"${touched[@]}"} | sort -u | paste -sd, -)"
    listed_csv="$(printf '%s\n' "${scopes[@]}" | grep -vx meta | sort | paste -sd, -)"
    if [ "$touched_csv" != "$listed_csv" ]; then
      echo "  FAIL: scopes ($scopes_csv) != touched splits (${touched_csv:-<none>})." >&2
      echo "        Touching only root files → chore(meta): … ; touching splits → list exactly those." >&2
      return 1
    fi
  fi

  echo "  ok: $header"
  return 0
}

failures=0
if [ -n "$RANGE" ]; then
  [ -n "$MSG_FILE" ] && { echo "--msg-file and --range are exclusive" >&2; exit 2; }
  mapfile -t shas < <(git log --reverse --format=%H "$RANGE")
  [ "${#shas[@]}" -gt 0 ] || { echo "no commits in range $RANGE" >&2; exit 2; }
  for sha in "${shas[@]}"; do
    echo "lint $sha"
    if ! lint_one "$(git log -1 --format=%B "$sha")" \
        "$(git diff-tree --no-commit-id --name-only -r --root "$sha")"; then
      failures=$((failures + 1))
    fi
  done
elif [ -n "$MSG_FILE" ]; then
  files_text=""
  [ -n "$FILES_FILE" ] && files_text="$(cat "$FILES_FILE")"
  lint_one "$(cat "$MSG_FILE")" "$files_text" || failures=1
else
  usage
fi

[ "$failures" = 0 ] || { echo "$failures commit(s) failed lint" >&2; exit 1; }
