#!/usr/bin/env bash
# Usage: test-image.sh <image-tag> [expected-zig-version]
set -euo pipefail

image="${1:?usage: test-image.sh <image-tag> [expected-zig-version]}"
expected_version="${2:-}"

appdir="$(mktemp -d)"
cid=""
cleanup() {
    if [[ -n "${cid}" ]]; then
        docker rm -f "${cid}" >/dev/null 2>&1 || true
    fi
    rm -rf "${appdir}"
}
trap cleanup EXIT

echo "== zig version =="
version="$(docker run --rm "${image}" zig version)"
echo "${version}"
if [[ -n "${expected_version}" && "${version}" != "${expected_version}" ]]; then
    echo "expected zig ${expected_version}, got ${version}" >&2
    exit 1
fi

echo "== user =="
user="$(docker run --rm "${image}" whoami)"
echo "${user}"
if [[ "${user}" != "dev" ]]; then
    echo "expected user dev, got ${user}" >&2
    exit 1
fi

echo "== detached keep-alive =="
cid="$(docker run -d "${image}")"
for _ in $(seq 1 10); do
    if [[ "$(docker inspect -f '{{.State.Running}}' "${cid}")" == "true" ]]; then
        break
    fi
    sleep 1
done
docker exec "${cid}" zig version
docker exec "${cid}" whoami
docker rm -f "${cid}" >/dev/null
cid=""

echo "== zig init / build / test / run =="
docker run --rm -v "${appdir}:/src" "${image}" zig init
docker run --rm -v "${appdir}:/src" "${image}" zig build
docker run --rm -v "${appdir}:/src" "${image}" zig build test
docker run --rm -v "${appdir}:/src" "${image}" zig build run

echo "OK ${image} (${version})"
