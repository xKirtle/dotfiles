# Audio

Stack: PipeWire + WirePlumber 0.5. Interface: **Focusrite Scarlett Solo 4th Gen** (USB),
using the kernel's Scarlett Gen 4 mixer driver.

## Inputs apps can see

| Source | What it is |
|---|---|
| **Scarlett Solo 4th Gen Input 2 Mic** (mono) | XLR mic. **Default input.** |
| **Scarlett Solo 4th Gen Input 1 Inst/Line** (mono) | instrument |
| Ryzen HD Audio Controller Analog Stereo | motherboard mic/line-in jack (could be disabled the same way as below) |

Set default by name (survives reboots):
`pactl set-default-source alsa_input.usb-Focusrite_Scarlett_Solo_4th_Gen_S14AD9G3B27480-00.HiFi__Mic2__source`

## How the Scarlett's inputs are built

The interface's capture device has **4 channels**: Input 1, Input 2 and a 2-channel loopback
(what the PC plays). PipeWire (UCM "HiFi" profile) exposes:
- a **raw 4-channel "split parent"** node, `alsa_input.hw_Gen_0`
- per-input sources carved out of it: Mic1 (AUX0), Mic2 (AUX1), Line2 = "Monitor Input 3+4" (AUX2/3)

**Recording from the raw node mixes both inputs together.** That's the "both inputs bundled"
symptom seen before. The raw node can't be removed (the per-input sources depend on it).

## WirePlumber rules (`~/.config/wireplumber/wireplumber.conf.d/`)

| File | Effect |
|---|---|
| `51-scarlett-raw-source.conf` | renames the raw node to "Scarlett Solo (raw, all inputs mixed)", `priority.session = 1` so it's never auto-default. It's now also marked internal and hidden from apps. |
| `52-disable-unused-inputs.conf` | disables the Scarlett loopback source (`…HiFi__Line2__source`, `node.disabled`) and the **webcam's audio device** (Angetube, `device.disabled`; video unaffected) |

Undo: delete the file and run `systemctl --user restart wireplumber`.
Inspect nodes: `wpctl status`, or `pw-dump` (JSON) for exact `node.name` / properties.

## Scarlett internal routing (hardware mixer)

Correct state, verified with `amixer -c 2` and `alsa-scarlett-gui` (AUR):
- PCM 01 ← DSP 1 ← **Analogue 1** (Input 1)
- PCM 02 ← DSP 2 ← **Analogue 2** (Input 2)
- PCM 03/04 ← Mix C / Mix D (loopback of PC playback)
- Mixer A/B → Hardware Outputs 1/2 (PC playback + direct monitoring of both inputs)

If inputs bleed into each other again, open `alsa-scarlett-gui`: PCM Inputs 1/2 must come
straight from DSP Outputs 1/2, not from a Mixer Output. Read it from the CLI:
`amixer -c 2 sget 'PCM 01'` / `'PCM 02'`. (Card number may change; check `/proc/asound/cards`.)
`alsa-utils` restores mixer state at boot (`alsa-restore.service`).

## Output switching: Super + `

- Script: `~/.local/bin/cycle-audio-output.sh` (original download in `~/Downloads`).
- Toggles default sink between `Scarlett Solo 4th Gen Headphones` and
  `Ryzen HD Audio Controller Digital Stereo` (S/PDIF speakers). Edit `SPEAKERS_MATCH` /
  `HEADPHONES_MATCH` if names change (`wpctl status` → Sinks).
- Fixed from the original: the speakers name didn't exist on this machine, and a guard was added so
  it notifies on a missing device instead of silently failing.
- No success notification; Caelestia's own toast shows the switch.

## Mic shortcuts

- Super + Mute: `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`
- Super + Volume Up/Down: `wpctl set-volume [-l 1] @DEFAULT_AUDIO_SOURCE@ 5%±`
  (PipeWire software level, on top of the interface's gain knob; capped at 100%)
- Visual: Caelestia bar mic icon (crossed out when muted) + mic OSD (see 03).

## Other notes

- The other output, `AD102 … (HDMI) [LG ULTRAGEAR+]`, is monitor audio through the GPU.
- In Chromium/web apps, mono sources may be presented as 2 channels; "Input 2" of a mono device
  may just duplicate "Input 1" (not confirmed).
