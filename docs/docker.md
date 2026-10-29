# Build cartridges with Docker

The repository-root `Dockerfile` builds pinned Asar 1.71 and includes the stock and
linked ROM builders. Docker, Git and a commercial USA ROM are sufficient; the ROM
is supplied at run time, never copied into the image. Both development repositories
use `feature/snes-link-8p`.

From a clone of this repository:

```sh
docker build -t smk-link-rom .
mkdir -p output
docker run --rm --network none --user "$(id -u):$(id -g)" \
  --mount 'type=bind,source=/absolute/path/Super Mario Kart (USA).sfc,target=/input/game.sfc,readonly' \
  --mount "type=bind,source=$PWD/output,target=/output" smk-link-rom
```

The output contains `stock-smk.sfc`, `linked-smk.sfc`, and `SHA256.json`. The stock
builder compares every byte with the supplied USA dump before publishing output.
It accepts an optional 512-byte copier header. Unsupported dumps fail validation.
Assets are extracted into a temporary directory. Keep generated cartridges private.
The runtime container needs no network access and the source ROM is read-only.

`docker run --rm smk-link-rom --help` documents alternative input/output paths.
On systems without `id`, omit `--user` or supply the desired numeric UID:GID.
The image builds the cartridges; it does not include an emulator. The companion
[Ares Docker instructions](../../ares/tools/link-lab/docker/README.md) explain how
to build its repository-root Dockerfile and play the linked cartridge.

A Git HTTPS proxy with a private CA can supply it transiently during the build:
`docker build --secret id=git_ca,src=/path/to/ca.pem -t smk-link-rom .`.
The CA is mounted only for Git fetching and is not retained in image layers.
