#!/bin/sh
# Proves that the image holds the versions of tools.lock. Run inside the image:
#   docker run --rm -v "$PWD/check-lock.sh:/check-lock.sh:ro" <image> sh /check-lock.sh [path to tools.lock]
# Exit code 0 when every tool is as locked, 1 when one differs.
set -u
lock="${1:-/opt/media-studio-render-base/tools.lock}"
failed=0

report() { # <ok|DIFFERS> <kind> <name> <locked> <found>
  printf '%-8s %-8s %-34s %s' "$1" "$2" "$3" "$4"
  [ "$1" = ok ] || printf '  (image has %s)' "$5"
  printf '\n'
  [ "$1" = ok ] || failed=$((failed + 1))
}

while read -r kind name version _; do
  case "$kind" in
    ''|'#'*) continue ;;
    apt) found="$(dpkg-query -W -f='${Version}' "$name" 2>/dev/null || true)" ;;
    pip) found="$(/opt/venv/bin/pip list --format=freeze --disable-pip-version-check 2>/dev/null \
        | awk -F'==' -v n="$name" '{ a = tolower($1); b = tolower(n); gsub(/[_.]/, "-", a); gsub(/[_.]/, "-", b) } a == b { print $2 }')" ;;
    dotnet) found="$(dotnet --list-runtimes 2>/dev/null | awk -v n="$name" '$1 == n { print $2 }' | head -1)" ;;
    link) if [ -e "$name" ] && [ "$(readlink "$name")" = "$version" ]; then found="$version"; else found="missing"; fi ;;
    model) ref="/opt/huggingface/hub/models--$(echo "$name" | sed 's#/#--#')/refs/main"
      if [ -s "$ref" ] && [ "$(cat "$ref")" = "$version" ]; then found="$version"; else found="missing"; fi ;;
    image|snapshot) continue ;; # build inputs, nothing to find in the image
    *) found="unknown kind" ;;
  esac
  if [ "$found" = "$version" ]; then report ok "$kind" "$name" "$version" "$found"; else report DIFFERS "$kind" "$name" "$version" "${found:-nothing}"; fi
done < "$lock"

if [ "$failed" -eq 0 ]; then echo "CHECK-LOCK ok"; else echo "CHECK-LOCK failed: $failed differ"; exit 1; fi
