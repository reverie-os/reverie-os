# Commit message format

All commits to the meta repo (`reverie-os/reverie-os`) and to the split
repos (`reverie-os/iso`, `reverie-os/nixconf`, …) must follow this format.
It is enforced by the `commit-msg` hook (`scripts/install-hooks.sh`) and by
the `commit-lint` CI workflow. History before this file predates the
convention and is grandfathered in.

## Format

```
type(scope1,scope2): one-line subject

[scope1]: scope-specific line
[scope2]: scope-specific line

Free-form body.
```

## Rules

1. **Header** — `type(scope,…): subject`
   - `type` is one of: `feat fix chore docs refactor test ci build perf
     style revert`.
   - `scope` is a split name (`iso`, `nixconf`, …) or `meta`.
     To add a scope: append it to `KNOWN_SCOPES` in
     `scripts/commit-lint.sh`, to the matrix in
     `.github/workflows/split.yml`, and to the root `flake.nix`.
   - Scopes are lowercase, comma-separated, sorted alphabetically, no
     duplicates: `feat(iso,nixconf): …`, not `feat(nixconf,iso): …`.
   - Subject is imperative, ≤ 72 chars, no trailing period.
2. **`meta` scope** — means the commit touches *no* split directory
   (root `flake.nix`/`flake.lock`, `.github/workflows/split.yml`, this
   file, `scripts/`, …). It must be the only scope: `chore(meta): …`.
   Root-level files riding along with a split change do *not* force a
   `meta` scope.
3. **Scope coverage (meta repo)** — the listed split scopes must equal the
   set of split directories touched by the commit. `git status` showing
   `iso/…` + `nixconf/…` requires `(iso,nixconf)`.
4. **Sections** — when more than one split scope is listed, every listed
   scope must have its own `[scope]:` section line in the body, so the
   future per-mini splitter (and today's human reader) can tell which
   part belongs where. Single-scope commits may omit the section.
   Section names must be listed scopes. There is never a `[meta]:`
   section.
5. **Merges / reverts** — `Merge pull request …`, `Merge branch …` and
   `Revert "…"` lines are exempt (produced by GitHub, not humans).

## Examples

Single scope (section optional):

```
feat(iso): bundle Firefox into the ISO image

Adds firefox to iso.nix packages.
```

Multi scope (sections required):

```
feat(iso,nixconf): wire installer module into ISO

[iso]: consume reverie-installer nixosModule in iso.nix
[nixconf]: expose reverie-installer module for the ISO to consume
```

Meta only:

```
chore(meta): document commit format
```

## Workflow

- Install the hook once per clone: `scripts/install-hooks.sh`.
- Bypass (`git commit --no-verify`) is still caught: CI lints every new
  commit on push and on pull requests.
- Split-repo contributors: the hook lives in the meta checkout
  (minis don't contain it — see limitation below), so mind the format
  and let CI tell you. Scope in a split repo must include that repo's
  own name, e.g. `fix(iso): …` in `reverie-os/iso`.
- v0.1 limitation: forward split copies the *full* message verbatim, so
  a multi-scope message appears in full in each mini. Sections keep it
  readable until the per-mini extractor lands.
