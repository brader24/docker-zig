# Zig 0.17.0 Docker toolchains

Dockerfiles that produce **toolchain images**. Build them here, then use the images from a Zig application repository.

| File | Image tag | Toolchain |
| --- | --- | --- |
| `Dockerfile.0.17.0` | `zig:0.17.0` | Zig **0.17.0** (tagged release) |
| `Dockerfile.dev` | `zig:dev` | Latest **development** build from `master` |

Both images install Zig, `git`, and CA certificates so `zig build` can fetch packages. They run as user `dev` (uid 1000) with passwordless `sudo`. Mount your application at `/src`.

With a TTY the container opens bash. Without one it stays running so you can `docker exec` in or attach VS Code.

## Build the images

From this repository:

```bash
docker build -f Dockerfile.0.17.0 -t zig:0.17.0 .
docker build -f Dockerfile.dev -t zig:dev .
```

`Dockerfile.dev` records the master tarball chosen at image-build time. To pick up a newer nightly:

```bash
docker build -f Dockerfile.dev --no-cache --build-arg CACHE_BUST=$(date -u +%Y-%m-%d) -t zig:dev .
```

Optional: publish so other machines can pull instead of building locally.

```bash
docker tag zig:0.17.0 ghcr.io/<owner>/zig:0.17.0
docker tag zig:dev     ghcr.io/<owner>/zig:dev
docker push ghcr.io/<owner>/zig:0.17.0
docker push ghcr.io/<owner>/zig:dev
```

Use your registry and image name in place of `ghcr.io/<owner>/zig`. After that, every example below can use that name instead of `zig:0.17.0` / `zig:dev`.

## Use from another repository

Work in the Zig **application** repo (the one with `build.zig`), not this toolchain repo. The image must already exist locally or in a registry.

### Interactive shell

```bash
docker run --rm -it -v "${PWD}:/src" zig:0.17.0
```

PowerShell:

```powershell
docker run --rm -it -v "${PWD}:/src" zig:0.17.0
```

Then:

```bash
zig build
zig build test
zig build -Doptimize=ReleaseSafe
```

Use `zig:dev` for the development compiler.

### Keep the container running

```bash
docker run -d --name zig-0.17.0 -v "${PWD}:/src" zig:0.17.0
docker exec -it zig-0.17.0 bash
```

### One-shot build

```bash
docker run --rm -v "${PWD}:/src" zig:0.17.0 zig build -Doptimize=ReleaseSafe
```

### VS Code Dev Container

1. Build or pull an image (`zig:0.17.0` or `zig:dev`, or a registry tag).
2. Copy `examples/devcontainer/` from this repo into the application repo as `.devcontainer/`.
3. If you published to a registry, change the `"image"` field in the copied JSON files to that tag.
4. Install the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension, open the **application** folder, and run **Dev Containers: Reopen in Container**.

| Copied file | Image |
| --- | --- |
| `.devcontainer/devcontainer.json` | `zig:0.17.0` |
| `.devcontainer/dev/devcontainer.json` | `zig:dev` |

The templates mount the app at `/src`, run as `dev`, install the [Zig language](https://marketplace.visualstudio.com/items?itemName=ziglang.vscode-zig) extension, and persist Zig caches in named volumes.

A minimal config if you would rather write it by hand:

```json
{
  "name": "Zig 0.17.0",
  "image": "zig:0.17.0",
  "workspaceFolder": "/src",
  "workspaceMount": "source=${localWorkspaceFolder},target=/src,type=bind,consistency=cached",
  "remoteUser": "dev",
  "overrideCommand": true
}
```

Replace `"image"` with `ghcr.io/<owner>/zig:0.17.0` (or similar) after you push.

### Build the image from a sibling checkout

If this toolchain repo sits next to the app and you do not want a pre-built tag, point the app's Dev Container at the Dockerfiles:

```json
{
  "name": "Zig 0.17.0",
  "build": {
    "dockerfile": "../zig/Dockerfile.0.17.0",
    "context": "../zig"
  },
  "workspaceFolder": "/src",
  "workspaceMount": "source=${localWorkspaceFolder},target=/src,type=bind,consistency=cached",
  "remoteUser": "dev",
  "overrideCommand": true
}
```

Paths are relative to the app's `.devcontainer/devcontainer.json`. Adjust `../zig` to wherever this repo actually is (including a git submodule).

### Application Dockerfile

```dockerfile
FROM zig:0.17.0
COPY . /src
RUN zig build -Doptimize=ReleaseSafe
```

## Image details

- Compiler: `/usr/local/zig/zig` (on `PATH`)
- User: `dev`
- Workdir / mount point: `/src`
- Local cache: `/tmp/zig-local-cache` (kept off bind-mounted source trees so `zig build` works on Docker Desktop for Windows)
- Global cache: `/var/cache/zig`

Override `ZIG_LOCAL_CACHE_DIR` / `ZIG_GLOBAL_CACHE_DIR` if you want the cache on a named volume from `docker run` as well.
