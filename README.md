# Zig 0.17.0 Docker toolchains

Two Dockerfiles for building [Zig](https://ziglang.org/) 0.17.0 applications:

| File | Toolchain |
| --- | --- |
| `Dockerfile.0.17.0` | Zig **0.17.0** (tagged release) |
| `Dockerfile.dev` | Latest **development** build from `master` |

Both images install the Zig compiler, `git`, and CA certificates so `zig build` can fetch packages. Source is expected at `/src`.

## Build the images

```bash
docker build -f Dockerfile.0.17.0 -t zig:0.17.0 .
docker build -f Dockerfile.dev -t zig:dev .
```

`Dockerfile.dev` records the master tarball chosen at image-build time. To pick up a newer nightly:

```bash
docker build -f Dockerfile.dev --no-cache --build-arg CACHE_BUST=$(date -u +%Y-%m-%d) -t zig:dev .
```

## Build an application

From a Zig project directory (the one with `build.zig`):

```bash
docker run --rm -v "${PWD}:/src" -w /src zig:0.17.0 zig build -Doptimize=ReleaseSafe
docker run --rm -v "${PWD}:/src" -w /src zig:dev zig build -Doptimize=ReleaseSafe
```

PowerShell:

```powershell
docker run --rm -v "${PWD}:/src" -w /src zig:0.17.0 zig build -Doptimize=ReleaseSafe
```

## Use as a base image

```dockerfile
FROM zig:0.17.0
COPY . /src
RUN zig build -Doptimize=ReleaseSafe
```

The compiler is on `PATH` at `/usr/local/zig/zig`.
