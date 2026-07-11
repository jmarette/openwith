#!/usr/bin/env bash
# Ensures every place that states the version agrees with dist-workspace.toml
# (the single source of truth, which release tags must also match).
set -euo pipefail

cd "$(dirname "$0")/.."

dist_version=$(sed -n 's/^version = "\(.*\)"$/\1/p' dist-workspace.toml | head -1)
swift_version=$(sed -n 's/.*public static let string = "\(.*\)".*/\1/p' \
  Sources/OpenWithCore/Model.swift | head -1)

fail=0
if [[ -z "$dist_version" ]]; then
  echo "error: could not read version from dist-workspace.toml" >&2
  fail=1
fi
if [[ "$dist_version" != "$swift_version" ]]; then
  echo "error: dist-workspace.toml ($dist_version) and OpenWithVersion ($swift_version) disagree" >&2
  fail=1
fi

if [[ -f Apps/project.yml ]]; then
  app_version=$(sed -n 's/^ *CFBundleShortVersionString: "\(.*\)"$/\1/p' Apps/project.yml | head -1)
  if [[ -n "$app_version" && "$dist_version" != "$app_version" ]]; then
    echo "error: dist-workspace.toml ($dist_version) and Apps/project.yml ($app_version) disagree" >&2
    fail=1
  fi
fi

if [[ "${GITHUB_REF:-}" == refs/tags/v* ]]; then
  tag_version="${GITHUB_REF#refs/tags/v}"
  if [[ "$dist_version" != "$tag_version" ]]; then
    echo "error: tag v$tag_version does not match dist-workspace.toml ($dist_version)" >&2
    fail=1
  fi
fi

if [[ "$fail" -eq 0 ]]; then
  echo "version OK: $dist_version"
fi
exit "$fail"
