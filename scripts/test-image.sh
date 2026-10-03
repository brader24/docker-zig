#!/usr/bin/env bash
# Usage: test-image.sh <image-tag> [expected-zig-version]
set -euo pipefail

# Git Bash otherwise rewrites -v /host:/src into a broken Windows path.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

image="${1:?usage: test-image.sh <image-tag> [expected-zig-version]}"
expected_version="${2:-}"

# Linux (GitHub Actions): bind-mount a host directory so the test matches
# `docker run -v ${PWD}:/src`. mktemp is owned by the runner (uid 1001) mode
# 0700; chmod lets image user `dev` (uid 1000) write it.
# Elsewhere: a named volume, because Docker Desktop bind-mounts of Windows
# paths are typically noexec (`zig build run` gets AccessDenied).
appdir=""
vol=""
cid=""
cleanup() {
    if [[ -n "${cid}" ]]; then
        docker rm -f "${cid}" >/dev/null 2>&1 || true
    fi
    if [[ -n "${vol}" ]]; then
        docker volume rm -f "${vol}" >/dev/null 2>&1 || true
    fi
    if [[ -n "${appdir}" && -d "${appdir}" ]]; then
        # Files created as uid 1000 are not removable by the GitHub runner
        # (uid 1001). chmod as root on the bind-mount first.
        docker run --rm --user 0 -v "${appdir}:/src" "${image}" \
            chmod -R a+rwx /src >/dev/null 2>&1 || true
        rm -rf "${appdir}" || true
    fi
}
trap cleanup EXIT

if [[ "$(uname -s)" == Linux ]]; then
    appdir="$(mktemp -d)"
    chmod a+rwx "${appdir}"
    src_mount="${appdir}:/src"
else
    vol="zig-test-$$"
    docker volume create "${vol}" >/dev/null
    src_mount="${vol}:/src"
fi

echo "== zig version =="
version="$(docker run --rm --user dev "${image}" zig version)"
echo "${version}"
if [[ -n "${expected_version}" && "${version}" != "${expected_version}" ]]; then
    echo "expected zig ${expected_version}, got ${version}" >&2
    exit 1
fi

echo "== user =="
user="$(docker run --rm --user dev "${image}" whoami)"
echo "${user}"
if [[ "${user}" != "dev" ]]; then
    echo "expected user dev, got ${user}" >&2
    exit 1
fi

echo "== detached keep-alive =="
cid="$(docker run -d --user dev "${image}")"
running="false"
for _ in $(seq 1 10); do
    if [[ "$(docker inspect -f '{{.State.Running}}' "${cid}")" == "true" ]]; then
        running="true"
        break
    fi
    sleep 1
done
if [[ "${running}" != "true" ]]; then
    echo "container did not stay running" >&2
    docker inspect "${cid}" >&2 || true
    docker logs "${cid}" >&2 || true
    exit 1
fi
docker exec --user dev "${cid}" zig version
docker exec --user dev "${cid}" whoami
docker rm -f "${cid}" >/dev/null
cid=""

echo "== zig init / build / test / run =="
docker run --rm --user dev -v "${src_mount}" "${image}" bash -c '
set -euo pipefail
user="$(whoami)"
echo "${user}"
if [[ "${user}" != "dev" ]]; then
    echo "expected user dev, got ${user}" >&2
    exit 1
fi
id
zig init
zig build
zig build test
zig build run
'

echo "OK ${image} (${version})"
