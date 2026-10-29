# Super Mario Kart disassembly and linked multiplayer

The original SNES ROM framework remains intact. The additions on
`feature/snes-link-8p` rebuild a byte-identical USA cartridge, then build an
experimental linked cartridge for 2–8 players in Grand Prix and balloon battle.
The companion Ares worker supplies synchronized inputs and individual views.

Build this repository's Docker image and supply your commercial USA ROM at run time:

```sh
docker build -t smk-link-rom .
```

See [Docker build/run instructions](docs/docker.md) for ROM/output mounts, and
[adapter documentation](docs/linked-multiplayer.md) for native builds and design.
The companion Ares repository has its own root Dockerfile and linked launcher.
ROM files and generated assets are not added by this implementation.
