#!/bin/sh
# Exports one version of this (private) repository to the public repository
# dferrandizmont/diapo, as a single commit without the private history.
#
#   sh tool/export_public.sh [--ref <git ref>] [--dest <dir>] [--apply]
#
#   --ref    what to export (default: the tag v<version> of pubspec.yaml if it
#            exists, else HEAD). Only committed, tracked files are exported
#            (git archive), so nothing in .gitignore or the working tree leaks.
#   --dest   the local clone of the public repository
#            (default: ../diapo-public next to the main checkout).
#   --apply  write the files into --dest and commit there. Without it the
#            script is a dry run: it only lists what would change.
#
# The commit is made as "Daniel Mont Ferrandiz <dev@mainshai.com>" with the
# message "feat: Diapo <version> (build <n>)". The script never pushes, tags or
# creates a release: that waits for the owner's OK.
#
# Private paths that never leave this repository are listed in EXCLUDES below.

set -eu

EXCLUDES='
.handoff.md
CLAUDE.md
.claude/
qa/
docs/reviews/
docs/security/
docs/competencia.md
docs/legal/NOTES.md
docs/store/
design/
release.json
store/
'

PUBLIC_NAME='Daniel Mont Ferrandiz'
PUBLIC_EMAIL='dev@mainshai.com'

die() { printf 'export_public: %s\n' "$*" >&2; exit 1; }

src=$(git rev-parse --show-toplevel) || die "run it inside the repository"
main_checkout=$(cd "$(git rev-parse --git-common-dir)/.." && pwd)
dest="$(dirname "$main_checkout")/diapo-public"
ref=''
apply=0

while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref=${2:?--ref needs a value}; shift 2 ;;
    --dest) dest=${2:?--dest needs a value}; shift 2 ;;
    --apply) apply=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

cd "$src"

pubspec_version=$(sed -n 's/^version: *//p' pubspec.yaml | tr -d '\r')
if [ -z "$ref" ]; then
  tag="v${pubspec_version%%+*}"
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    ref=$tag
  else
    ref=HEAD
  fi
fi
git rev-parse -q --verify "$ref^{commit}" >/dev/null || die "no such ref: $ref"

full_version=$(git show "$ref:pubspec.yaml" | sed -n 's/^version: *//p' | tr -d '\r')
version=${full_version%%+*}
build=${full_version#*+}
[ -n "$version" ] && [ "$build" != "$full_version" ] || die "cannot read version+build from pubspec.yaml at $ref"
message="feat: Diapo $version (build $build)"

[ -d "$dest/.git" ] || die "not a git repository: $dest"
dest=$(cd "$dest" && pwd)
# The destination must be the public repository, never this one or a clone of
# it: another git directory, and without the first commit of this history.
src_git=$(cd "$(git rev-parse --git-common-dir)" && pwd)
dest_git=$(cd "$dest" && cd "$(git rev-parse --git-common-dir)" && pwd)
[ "$src_git" != "$dest_git" ] || die "$dest is this repository, not the public one"
roots=$(git rev-list --max-parents=0 HEAD) || die "could not read the first commit of this history"
[ -n "$roots" ] || die "could not read the first commit of this history"
for root in $roots; do
  if git -C "$dest" cat-file -e "$root^{commit}" 2>/dev/null; then
    die "$dest holds the private history; point --dest at the public repository"
  fi
done
# Untracked files count too: a failed apply cleans the destination back.
dest_status=$(git -C "$dest" status --porcelain --untracked-files=all) ||
  die "could not read the status of $dest"
[ -z "$dest_status" ] || die "$dest has uncommitted or untracked files; clean it first"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
tree="$work/tree"
mkdir -p "$tree"

# Tracked files only, with the line endings of .gitattributes. Two steps so a
# failure of either one stops the script (set -e does not see into a pipe).
git archive --format=tar -o "$work/tree.tar" "$ref" || die "git archive failed"
tar -xf "$work/tree.tar" -C "$tree" || die "could not unpack the archive"
rm -f "$work/tree.tar"

for path in $EXCLUDES; do
  rm -rf "${tree:?}/${path%/}"
done

# Safety checks on what would be published.
secrets=$(cd "$tree" && find . -type f \( -name '*.jks' -o -name '*.keystore' \
  -o -name 'key.properties' -o -name '*.p12' -o -name '*.p8' -o -name '*.mobileprovision' \
  -o -name '.env' -o -name '.env.*' -o -name 'google-services.json' \
  -o -name 'GoogleService-Info.plist' -o -name '*service-account*.json' \)) ||
  die "could not list the files to check them"
[ -z "$secrets" ] || die "refusing to export secret-looking files:
$secrets"

# git grep exits 0 on a match, 1 on none and 2 or more on an error: only 1 is
# clean. Not plain grep: Git for Windows' grep aborts on this tree.
scan() {
  # $1 = what, then grep options and patterns
  what=$1
  shift
  set +e
  hits=$(cd "$tree" && git grep --no-index -l "$@" -- . \
    ':!.githooks/check-identity.sh' ':!tool/export_public.sh')
  rc=$?
  set -e
  case $rc in
    0) die "files contain $what:
$hits" ;;
    1) ;;
    *) die "could not search the files for $what" ;;
  esac
}
personal="dferrandizmont@$(printf 'gmail').com"
scan 'the personal e-mail' -i -F -e "$personal"
# Local paths of the owner's machines (user folders, the private notes).
scan 'a local path' -I -E -e '[A-Za-z]:[/\\]+Users[/\\]+' -e '/Users/[A-Za-z]' -e 'nuevos-proyectos'


# What changes in the public repository. Every list is written to a file in
# its own step, so a failing command stops the script before the destination
# is touched.
(cd "$tree" && find . -type f) >"$work/found.txt" || die "could not list the export"
sed 's|^\./||' "$work/found.txt" >"$work/new-raw.txt" || die "could not list the export"
LC_ALL=C sort "$work/new-raw.txt" >"$work/new.txt" || die "could not sort the export"
git -C "$dest" ls-files >"$work/old-raw.txt" || die "could not list $dest"
LC_ALL=C sort "$work/old-raw.txt" >"$work/old.txt"
LC_ALL=C comm -13 "$work/old.txt" "$work/new.txt" >"$work/added.txt"
LC_ALL=C comm -23 "$work/old.txt" "$work/new.txt" >"$work/removed.txt"
LC_ALL=C comm -12 "$work/old.txt" "$work/new.txt" >"$work/common.txt"
# Compare blob ids in two processes instead of one cmp per file (slow on Windows).
(cd "$tree" && git hash-object --no-filters --stdin-paths <"$work/new.txt") >"$work/ids.txt" ||
  die "could not hash the export"
[ "$(wc -l <"$work/ids.txt")" -eq "$(wc -l <"$work/new.txt")" ] || die "hashing the export lost files"
paste "$work/new.txt" "$work/ids.txt" >"$work/new-ids-raw.txt" || die "could not pair the hashes"
LC_ALL=C sort "$work/new-ids-raw.txt" >"$work/new-ids.txt" || die "could not sort the hashes"
git -C "$dest" ls-files -s >"$work/stage.txt" || die "could not read the index of $dest"
sed 's/^[0-9]* \([0-9a-f]*\) [0-9]*\t\(.*\)$/\2\t\1/' "$work/stage.txt" >"$work/old-ids-raw.txt" ||
  die "could not read the index of $dest"
LC_ALL=C sort "$work/old-ids-raw.txt" >"$work/old-ids.txt" || die "could not sort the index of $dest"
LC_ALL=C comm -13 "$work/old-ids.txt" "$work/new-ids.txt" >"$work/differ-ids.txt" || die "could not compare the hashes"
cut -f1 "$work/differ-ids.txt" >"$work/differ.txt" || die "could not compare the hashes"
LC_ALL=C comm -12 "$work/differ.txt" "$work/common.txt" >"$work/changed.txt"

count() { wc -l <"$1" | tr -d ' '; }
show() {
  # $1 = label, $2 = list
  n=$(count "$2")
  printf '%s: %s\n' "$1" "$n"
  head -n 40 "$2" | sed 's/^/  /'
  [ "$n" -le 40 ] || printf '  ... and %s more\n' "$((n - 40))"
}

printf 'Export %s (%s, %s) -> %s\n' "$ref" "$(git rev-parse --short "$ref")" "$message" "$dest"
printf 'Files to publish: %s\n' "$(count "$work/new.txt")"
show 'Added' "$work/added.txt"
show 'Changed' "$work/changed.txt"
show 'Removed' "$work/removed.txt"

if [ "$apply" -ne 1 ]; then
  printf '\nDry run: nothing written. Run again with --apply to commit in %s.\n' "$dest"
  exit 0
fi

total=$(( $(count "$work/added.txt") + $(count "$work/changed.txt") + $(count "$work/removed.txt") ))
[ "$total" -gt 0 ] || { printf 'Nothing to commit: the public repository already matches.\n'; exit 0; }
[ -f "$tree/.githooks/check-identity.sh" ] || die "the export has no .githooks/check-identity.sh; refusing to commit without the identity check"

# From here on the destination changes. It was clean, so on any failure the
# script puts it back as it was (tracked files from HEAD, new files removed).
rollback() {
  printf 'export_public: failed; restoring %s\n' "$dest" >&2
  git -C "$dest" reset -q --hard HEAD && git -C "$dest" clean -q -fd
}
trap 'rc=$?; if [ "$rc" -ne 0 ]; then rollback; fi; rm -rf "$work"' EXIT
trap 'exit 1' INT TERM

# Mirror the tree: remove the tracked files, copy the new ones in.
git -C "$dest" ls-files -z >"$work/remove.z"
(cd "$dest" && xargs -0 rm -f <"$work/remove.z")
(cd "$tree" && tar -cf "$work/copy.tar" .)
(cd "$dest" && tar -xf "$work/copy.tar")
find "$dest" -mindepth 1 -type d -empty -not -path "$dest/.git*" -delete 2>/dev/null || true

export GIT_AUTHOR_NAME="$PUBLIC_NAME" GIT_AUTHOR_EMAIL="$PUBLIC_EMAIL"
export GIT_COMMITTER_NAME="$PUBLIC_NAME" GIT_COMMITTER_EMAIL="$PUBLIC_EMAIL"
cd "$dest"
git add -A
sh .githooks/check-identity.sh staged || die "identity check failed; nothing committed"
git -c user.name="$PUBLIC_NAME" -c user.email="$PUBLIC_EMAIL" commit -q -m "$message"
printf '\nCommitted %s in %s as %s <%s>.\n' "$(git rev-parse --short HEAD)" "$dest" "$PUBLIC_NAME" "$PUBLIC_EMAIL"
printf 'Not pushed. Check it, then push with the owner'\''s OK: git -C %s push\n' "$dest"
