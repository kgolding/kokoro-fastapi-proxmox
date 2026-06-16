# Kokoro-FastAPI on Proxmox (LXC)

A one-command installer for [Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI) — a Dockerized, OpenAI-compatible text-to-speech API built around the Kokoro-82M model — as an LXC container on Proxmox VE.

This follows the same pattern as the [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) "Helper-Scripts" project: a small host-side script creates the container (using their shared `build.func` framework for storage/network selection, the install wizard, etc.), then an in-container script installs Docker and runs Kokoro-FastAPI.

> This is an independent, unofficial script. It is not part of the official community-scripts/ProxmoxVE repo (no script for Kokoro-FastAPI exists there yet) and it is not affiliated with the upstream Kokoro-FastAPI project.

## What it sets up

- A new Debian 13 LXC container (default: 4 vCPU / 4096 MB RAM / 12 GB disk — all adjustable)
- Docker Engine + Compose plugin inside the container
- Kokoro-FastAPI running as a Docker container with `restart: unless-stopped`, using the official pre-built `ghcr.io/remsky/kokoro-fastapi-cpu` image, port 8880

## Prerequisites

- A working Proxmox VE node (8.x or 9.x) with internet access, since the script pulls `build.func` from GitHub and the container pulls its Docker image from `ghcr.io`
- A Debian/Ubuntu LXC template available (the script will offer to download one if missing)

## Install

1. Push this repo to your own public GitHub repo (it defaults to `github.com/kgolding/kokoro-fastapi-proxmox` - edit `KOKORO_REPO_URL` near the bottom of `ct/kokoro-fastapi.sh` if you fork it elsewhere), keeping the `ct/` and `install/` folders at the repo root.
2. On the Proxmox shell (the host, not inside a container), run:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kgolding/kokoro-fastapi-proxmox/main/ct/kokoro-fastapi.sh)"
```

3. Follow the prompts (Default for a quick setup with the values above, or Advanced to change CPU/RAM/disk/storage/network/etc).

### Why you'll see one harmless-looking error

Partway through, you'll likely see a line like `curl: (22) The requested URL returned error: 404`. That's expected: `build.func` (the shared framework this script borrows from community-scripts/ProxmoxVE) always tries to fetch the app's installer from the *official* community-scripts catalog first, and Kokoro-FastAPI isn't listed there. `ct/kokoro-fastapi.sh` notices that and runs the real installer from this repo instead, right afterward - look for "Installing Kokoro-FastAPI (custom script - not yet in community-scripts)" a moment later in the output, which is the part that actually does the work.

When it finishes, it prints the container's IP and three URLs:

- Web UI: `http://<container-ip>:8880/web`
- OpenAI-compatible endpoint: `http://<container-ip>:8880/v1`
- API docs: `http://<container-ip>:8880/docs`

Example using the OpenAI Python SDK against it:

```python
from openai import OpenAI

client = OpenAI(base_url="http://<container-ip>:8880/v1", api_key="not-needed")

with client.audio.speech.with_streaming_response.create(
    model="kokoro",
    voice="af_sky+af_bella",
    input="Hello world!",
) as response:
    response.stream_to_file("output.mp3")
```

## Updating

Re-run the exact same command from step 2 above against the same Proxmox host. `build.func` detects the existing container and offers to run the update routine instead of creating a new one, which does `docker compose pull && docker compose up -d` inside the container to grab the latest image.

You can also update manually:

```bash
pct enter <CTID>
cd /opt/kokoro-fastapi
docker compose pull
docker compose up -d
```

## GPU acceleration (optional, manual)

Kokoro-FastAPI also ships an NVIDIA GPU image (`ghcr.io/remsky/kokoro-fastapi-gpu`) that's roughly 10-30x faster than CPU. The install script will use it automatically, **but only if `nvidia-smi` already works inside the container before the script runs** — i.e. only if you've already passed an NVIDIA GPU through to that specific LXC and installed a matching driver yourself.

This script deliberately does not try to automate that part. NVIDIA passthrough into LXC (as opposed to a VM) requires the driver version inside the container to match the Proxmox host's driver exactly, plus manual `pct config` device entries (`/dev/nvidia0`, `/dev/nvidiactl`, `/dev/nvidia-uvm`, etc.). It's a well-trodden path, but version mismatches (e.g. after a Proxmox kernel/driver update) are a common source of breakage, and a script can't safely guess your host's driver version for you. If you want to set this up:

1. Install the NVIDIA driver on the Proxmox host itself.
2. Create the container (e.g. via this script, in CPU mode), then add the device passthrough entries to its config and install the *same version* NVIDIA driver inside the container (no kernel module, just the userspace libraries — install with `--no-kernel-module`).
3. Confirm `nvidia-smi` works inside the container.
4. Re-run `install/kokoro-fastapi-install.sh` inside the container (or just `pct enter <CTID>` and reinstall manually) — it will detect the GPU and switch images.

For AMD ROCm (`ghcr.io/remsky/kokoro-fastapi-rocm`), the same logic applies but isn't auto-detected by this script at all; edit `/opt/kokoro-fastapi/docker-compose.yml` by hand if you want to try it.

## Customizing

Edit `/opt/kokoro-fastapi/docker-compose.yml` inside the container, then `docker compose up -d` to apply. A few environment variables you can set there (see upstream `core/config.py` for the full list):

- `API_LOG_LEVEL` — `DEBUG` (default upstream), `INFO`, `WARNING`, `ERROR`
- `TARGET_MIN_TOKENS` / `TARGET_MAX_TOKENS` / `ABSOLUTE_MAX_TOKENS` — control the sentence-chunking behavior for long-form input

If you'd rather pin a specific release instead of `:latest` (recommended by upstream for production use), change the image tag to a version from the [Kokoro-FastAPI releases page](https://github.com/remsky/Kokoro-FastAPI/releases) or its [package list](https://github.com/remsky/Kokoro-FastAPI/pkgs/container/kokoro-fastapi-cpu).

## Files

```
ct/kokoro-fastapi.sh             # run this on the Proxmox host - creates/updates the LXC
install/kokoro-fastapi-install.sh # runs inside the LXC - installs Docker + Kokoro-FastAPI
```

## Credits

- [Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI) by [remsky](https://github.com/remsky) — Apache-2.0
- [Proxmox VE Helper-Scripts](https://github.com/community-scripts/ProxmoxVE) (originally by tteck, now community-maintained) — MIT, provides the `build.func`/`tools.func` framework these scripts build on

## License

MIT for the scripts in this repo (see `LICENSE`). Kokoro-FastAPI itself is licensed Apache-2.0 by its authors.
