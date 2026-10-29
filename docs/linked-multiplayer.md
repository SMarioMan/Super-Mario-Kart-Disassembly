# Linked Super Mario Kart for 2–8 players

Both this repository and `SMarioMan/ares` use branch `feature/snes-link-8p`. The
original disassembly remains unchanged. Separate tools rebuild the stock USA ROM
exactly, then produce a linked cartridge for the companion Ares frontend.

## Verified stock baseline

Use Asar **1.71**, the version documented by this framework. Asar 1.91 rejects the
non-static label expressions in the split SPC700 engine insertion.

```sh
. /workspace/toolchain/activate.sh
python3 tools/build_stock.py '/path/to/Super Mario Kart (USA).sfc' \
  --asar /workspace/toolchain/asar171-build/asar/asar-standalone \
  --output /workspace/build/stock-smk.sfc
```

The helper checks the USA dump's MD5 `7f25ce5a283d902694c52fb1152fa61a`, strips an
optional 512-byte copier header, extracts 132 assets using the repository's pointer
table and verified supplementary ROM slices, joins the split BRR sample, and runs initialization, SPC700, assembly, and
finalization passes in a temporary copy. Source and assets in the checkout are not
overwritten. Output is replaced only after **byte equality** with the supplied dump
succeeds. The validated output is 524,288 bytes, SHA-256:

`2ada8919688087be60a6a48cace8f877add60c45d2e5d09e2442faa55be62a49`

The rebuilt stock ROM boots in the compiled Ares desktop frontend at 60 VPS. ROMs,
extracted assets, screenshots, firmware, and generated files stay outside Git. The
user's supplied ROM is the source of the extracted assets.

## Build and play

```sh
python3 tools/build_linked.py /workspace/build/stock-smk.sfc \
  --asar /workspace/toolchain/asar171-build/asar/asar-standalone \
  --output /workspace/build/linked-smk.sfc
```

The linked builder requires the verified stock SHA-256. `player_storage.py` relocates 72
explicitly identified per-player operands, verifying the original instruction bytes and
lengths against the address-labelled disassembly. It does not search and replace
arbitrary ROM data. `linked_patch.asm` then installs the adapter and expands the
cartridge to 1 MiB while retaining DSP1 support.

Build Ares's optional `ARES_BUILD_LINK_LAB` target and use `tools/link-lab/play.py` in
the companion repository. Its [README](../../ares/tools/link-lab/README.md) documents
Docker builds, local/host/join commands, keyboard/gamepad controls, protocol behavior, validation commands,
and limitations. The host selects 2–8 connected players. Each reserves a unique
character in the lobby before boot; in Grand Prix, native CPU driving fills the remaining kart slots
with unused characters. Player 1 controls class/cup selection and pause; the native
character screen preserves the reservation. An optional host course ID 0–19 overrides
native cup progression for testing. Use host/local `--mode battle` for native balloon battle on all four arenas, with
2–8 humans and no CPU vacancies. Each starts with three balloons; eliminated clients
spectate a living racer, and player 1 advances victories/draws into a rematch. Slot
colors are blue, red, green, yellow, purple, cyan, orange and pink, independently of
character choice. In Grand Prix, all connected players remain qualified for subsequent races, regardless of finishing place.
Once every human finishes, remaining CPUs are ranked in their current native order so
absent controllers never block results.

The repository-root [Dockerfile](../Dockerfile) builds the cartridges from a read-only
commercial ROM mount. See [standalone Docker commands](docker.md); the companion
Ares repository has its own root Dockerfile for building/running the emulator.

## Adapter design

| Area | Implementation |
| --- | --- |
| Controls | Eight live words at `$21C0–$21CF`, an atomic strobe at `$21DC`, frozen inputs at `$21E0–$21EF` / `$33A0–$33AF`, independent pressed-edge latches; only the host reaches native menu input |
| Racers | The first N `$1000–$17FF` records use human physics; Grand Prix vacancies use native CPU driving, while battle vacancies are inactive. Characters are unique |
| Dispatch | Deterministic human/CPU updates replace the original two-human schedule; temporary borrowed host input/coin context is restored |
| Storage | Eight handling tables and extended coins, inventory, input, pointer, and event arrays in serialized link RAM |
| Items | Pickup, roulette/use, and item effects execute once per shared tick for every racer, including racers outside the host camera |
| Lakitu | Eight independent native interpreter contexts and timers, first-viewport projection, separate penalties and simultaneous rescues |
| Starts | All eight starting-line inhibit flags clear together |
| Finishes | Native finish queue records all eight; results wait for every connected human, complete unfinished CPUs in current rank order, and preserve eight unique ranks |
| Results | Lower-four elimination is removed; native standings/points, next-course transitions, awards, and another cup remain available |
| Native history | Extra racers cannot index the original two-player history arrays |
| Local views | Emulator-only private presentation passes use native projection/OAM drawing, with world updates gated off and the full core restored |
| HUD | Private kart identity, camera, rank, coins, and inventory icon follow the local reservation; item icon redraw never runs item logic |

The ABI exposes `LNK1`, capacity, roster, host course, frame, connected-human count, and
a private presentation flag and host mode register `$21DD`. Eight KiB of scratch RAM
is mapped at `$00–$0F,$80–$8F:$3000–$3FFF` and `$5000–$5FFF`,
**not** `$6000`, which belongs to DSP1. The full register table is in the companion
README. Ordinary desktop Ares does not map this device; use the linked worker for the
linked cartridge.

Canonical simulation never depends on the client's local index. All instances receive
the same eight-pad bundle for each agreed frame. A single atomic game latch prevents
updates spanning video frames from mixing different bundles. Peers hash the synchronized
core plus link state before the next bundle is released. A mismatch stops play. Private
camera rendering uses a full run-ahead save/restore, skips rasterization of intermediate
pipeline frames, suppresses output filters/resampling, and restores link RAM. Shared
race clocks, lap checks, inventories, and physics do not advance in those passes.
Interactive clients perform those passes in a separate background renderer, using a
cached synchronized snapshot. Source-frame and race-generation checks reject stale or
future images; a busy renderer drops intermediate pictures. Canonical input/audio run
at native NTSC cadence independently of private rendering. Menus, host pause screens, and completed-race results use the canonical
host view. Two CPU cores per client are recommended.

Battle adds 24 native balloon objects at `$5000–$5BFF` and eight native item/projectile
objects at `$5C00–$5FFF`. Both item allocation and the native graphics-cache pointer
table are relocated; the original battle reused the added racers' memory. Every live
human participates in native item contact independently of viewport visibility. Red
shells choose the nearest living opponent deterministically. Native balloon scripts
perform losses and pop animations; the shared world handles elimination and results.

Private rendering preserves object links, graphics storage/cache assignments and the
foreground animation interpreter while borrowing local kart simulation data. A ROM
completion counter at `$3CD8` acknowledges three complete drawing passes, then waits
for final OAM/VRAM upload. This avoids assuming crowded battle scenes finish in three
video frames. World/link state and canonical audio are restored afterward. The worker's
balloon-only OBJ color extension supports the eight shaded colors without rewriting
shared kart/item CGRAM. Both SNES PPU implementations expose the optional color hook;
the worker uses the performance PPU. Other emulator frontends leave it unset.

Protocol `ares-link-lab/2`, the expanded device RAM and SFC serializer `v147-link1`
require matching current builds and fresh diagnostic checkpoints. Older save states
are rejected; they are not silently interpreted using the new layout.

## Executable checks

The companion tests exercise real 65816 gameplay rather than only packets:

- Independent acceleration and motion for each of eight human racers.
- Independent star activation; all nine item types for every player; status timers
  ticking once per game update, Boo theft across all 56 player pairs, and lightning
  against all seven opponents.
- Every connected-player count 2–8, native CPU vacancies, CPU inventory use,
  human-only completion barriers, and eight unique resulting ranks.
- All eight simultaneous native off-track rescues, separate penalties, and
  resumed player control.
- Real item-box and coin pickup for every racer outside the host camera.
- Deterministic replay from a matching diagnostic snapshot.
- Real final-lap finish crossings, eight unique ranks, waiting for all finishers,
  five-race cup progression, awards, and a new cup with clean inventories.
- All twenty course IDs with rotated character rosters, reserved character
  selection, host pause/resume, and guest menu/pause exclusion.
- Different local video with equal canonical state and audio, including a local
  inventory icon that differs independently of the host's icon and preserves native
  pending/stolen blink phases. Background-rendered images match synchronous source
  frames without changing canonical hashes or audio.
- Eight independent emulator processes comparing every frame barrier, plus
  protocol conflict, authority, malformed-message, disconnect, timeout, and
  divergence checks.
- Actual SDL video/aspect, keyboard input/release, and quit on a virtual X11
  display; the real host/join launchers, multiple windows, and session shutdown.

`link_input_probe.asm` is an independent asset-free diagnostic that reads all eight MMIO
pad words into WRAM with actual 65816 loads. The worker checks eleven input patterns
with `test_probe.py`.

Tests seed inventory and final-lap states where stated; they do not claim eight humans
naturally drove five entire courses. Physical gamepads, eight-human LAN sessions,
cross-platform determinism, Internet latency, and rare native game situations require
further qualification. The audio mix remains the shared native host mix. This is a
playable experimental adapter, not a claim of exhaustive Nintendo-level polish or
licensed-hardware compatibility.

## Generalization and physical hardware

Transport, session identity, unique reservations, host authority, frame barriers, and
divergence handling live outside the game adapter. F-Zero would need its own ROM changes
for human controls, cameras, items/results as applicable, and tests; it is not supported
just by selecting four peers.

The MMIO link device and extra scratch memory currently exist only in the emulator. No
officially licensed expansion device, physical cabling, timing, or firmware has been
implemented or verified. Satellaview and XBAND cannot be claimed to provide this
eight-console interface without that work and actual hardware tests. Real hardware
remains an optional future backend for the ABI.