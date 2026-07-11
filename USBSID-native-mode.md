# USBSID-Pico native mode (OM_USBSID_PICO_NATIVE)

In native mode the library uploads the SID file to the USBSID-Pico, which
emulates the complete C64 (6510 CPU, CIAs, VIC timing) on the RP2350 and
plays the tune itself. The Amiga side only selects subtunes and
starts/stops/pauses playback — the local 6502 emulation is bypassed
entirely.

Requires a Pico2 (rp2350) board running a firmware built with
`ONBOARD_SIDPLAYER` (firmware files ending in `_sp`).

## Protocol

All commands are sent over the same CDC bulk pipe as regular register
writes, wrapped in a `SID_COMMAND|SID_CONFIG` (`0xD2`) packet. The upload
sequence follows the reference `send_sid` tool from the firmware repo:

| Packet | Meaning |
|---|---|
| `D2 D0 <type>` | Upload start (`01` = SID, `02` = PRG) |
| `D2 D1 <62 data bytes>` | File data — always a full 64-byte packet, the firmware unconditionally consumes 62 bytes per packet |
| `D2 D2` | Upload end |
| `D2 D3 <hi> <lo>` | File size, 16-bit big-endian, sent *after* upload end |
| `D2 E0 <tuneid> <subtune>` | Select subtune (0-based) — device starts playback by itself |
| `D2 E1` | Start playback |
| `D2 E2` | Stop playback (only acts while playing) |
| `D2 E3` | Pause — a toggle |
| `D2 E4` / `D2 E5` | Next / previous subtune |
| `D2 E6` | Force output on socket two |

Library mapping:

| playsid.library call | Native mode behavior |
|---|---|
| `SetModule` | Uploads PSID header + C64 data as one file. On failure clears the module flag so `StartSong` returns `SID_NOMODULE` |
| `StartSong` | Sends stop, then subtune select (device auto-starts) |
| `StopSong` | Sends stop; if paused, unpauses first (device ignores stop while paused) |
| `PauseSong` / `ContinueSong` | Sends the pause toggle, host tracks play state |
| `ForwardSong` / `RewindSong` | No-op, not supported by the device |

## Limitations in native mode

Because no C64 emulation runs on the Amiga, all features that depend on
observing the emulated state are unavailable:

- **Forward / rewind** — no device command exists.
- **Per-voice muting** (`SetChannelEnable`) — no device command exists.
- **Time counter / song position** — the library cannot know where the
  tune is; player time displays will not advance.
- **Song end detection** — same reason.
- **Scope / waveform display** (`DisplayData`) — no SID register traffic
  passes through the library.
- **`GetSongSpeed`** — reports nothing useful; the device derives PAL/NTSC
  timing from the PSID header itself (`SetVertFreq` is ignored).
- **Firmware detection** — there is no way to ask the device whether it
  runs an `_sp` firmware. With a normal firmware all player commands are
  silently ignored (firmware `config.c` hits `default: break`) and no
  sound is produced. The library returns `SID_NOUSBSIDPICO` when no
  device is present, and `SID_NOMODULE` when the upload fails, but a
  wrong-firmware device cannot be distinguished from a working one.

## Firmware protocol limitations

Properties of the current onboard-player protocol that constrain what a
host can implement. Documented here both as the rationale for the
library limitations above and as a starting point for future firmware
work:

- **No capability detection.** Nothing reports whether the firmware was
  built with `ONBOARD_SIDPLAYER`; the version string (`0.7.1-<hash>`)
  does not encode it. A host cannot fail gracefully on a non-`_sp`
  firmware.
- **No acknowledgements.** Neither the upload sequence nor the player
  commands return any response, so an upload cannot be verified (byte
  count, checksum) and command success cannot be observed.
- **No playback state query.** Playing/paused/stopped, current subtune
  and elapsed frames/seconds cannot be read back. This is what rules
  out time displays and song end detection (playlist auto-advance) on
  the host.
- **Pause is a toggle.** `SID_PLAYER_PAUSE` flips state; if host and
  device disagree about the current state (e.g. after another tool
  touched the device), pause and resume invert. The library tracks
  state host-side but cannot resynchronize.
- **Stop is dropped while paused.** `SID_PLAYER_STOP` only takes effect
  while `sidplayer_playing` is true. The library works around this by
  unpausing first.
- **No fast forward.** There is no "run the emulation N frames without
  waiting" command, so seek/forward cannot be implemented.
- **No per-voice mute.** Individual SID voices cannot be muted during
  onboard playback.
- **Upload framing is undocumented.** The mandatory 64-byte packets,
  62 data bytes per packet, `UPLOAD_SID_END` *before* `UPLOAD_SID_SIZE`
  and the 16-bit size are only discoverable from the `send_sid` example
  source.
- **No voice-state feed back to the host.** The firmware keeps a SID
  register mirror (`sid_memory` at `$D400` in the shared C64 memory)
  but does not expose it. A periodic packet with that mirror
  (~28 bytes/frame for one SID, ~80 for three — under 1% of full-speed
  USB at 50 Hz) would restore host-side scope/waveform displays and
  per-voice UI data, and with a frame counter would give the host a
  time position. Batching a few frames per packet would keep the host
  interrupt rate down. Note that envelope levels are not part of the
  write mirror (real SIDs only expose `ENV3`), so a host would
  approximate them from gate + ADSR values.
