# Audio

"Bubbly" — Colbie Caillat. Two encodes of one master, because no single format
covers every browser: Safari only gained Opus support in 17, so iOS 16 and older
need the AAC fallback. `<audio>` picks the first one it can play.

| file | codec | size |
| --- | --- | --- |
| `bubbly.opus` | Opus 64k VBR | 1.7 MB |
| `bubbly.m4a` | AAC 96k | 2.3 MB |

The 320 kbps master (7.9 MB) is not in the repo — it is 12x the weight of the
rest of the site and nothing on the page needs that fidelity for background
music. Keep it wherever you keep the original; these two files are regenerated
from it like so.

## Regenerating

Measure the master first — `loudnorm` is two-pass, and the second pass needs the
numbers from the first:

```sh
ffmpeg -i song.mp3 -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json -f null -
```

Substitute the reported `input_i` / `input_tp` / `input_lra` / `input_thresh` /
`target_offset` into `measured_*` / `offset` below (the values here are from the
current master), then encode:

```sh
NORM="loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=-16.90:measured_TP=-0.46\
:measured_LRA=5.50:measured_thresh=-26.99:offset=-0.21:linear=true"

ffmpeg -i song.mp3 -map a:0 -map_metadata -1 -af "$NORM" \
  -c:a libopus -b:a 64k -vbr on -application audio -ar 48000 bubbly.opus

ffmpeg -i song.mp3 -map a:0 -map_metadata -1 -af "$NORM" \
  -c:a aac -b:a 96k -ar 44100 -movflags +faststart bubbly.m4a
```

Why each flag matters:

- `-map_metadata -1` drops ID3 tags and embedded album art, which would
  otherwise ride along as dead weight in every download.
- `loudnorm` to -16 LUFS puts the track at a predictable level, so the 0.45
  volume `main.js` sets means the same thing regardless of which master this was
  cut from. `TP=-1.5` leaves peak headroom that lossy encoding needs.
- `-movflags +faststart` moves the MP4 index ahead of the audio data so
  playback can begin before the file has finished downloading. Without it a
  guest on a slow connection waits for all 2.3 MB.
- 48 kbps Opus was tried and rejected: it saves 400 KB and puts audible
  artifacts on the acoustic guitar.
