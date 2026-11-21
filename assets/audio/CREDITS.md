# Audio credits

Every sound here is free to use in a commercial game without attribution.
Credits are listed anyway, as thanks and so we always know where things came from.

## Recorded sounds (CC0 / public domain, from OpenGameArt.org)

| File | Source | Author |
|---|---|---|
| `rain_light.ogg`, `rain_heavy.ogg` | [Rain (Loopable)](https://opengameart.org/content/rain-loopable), files 4 and 2 | ylmir |
| `rain_roof.ogg` | [amb rain loop 2](https://opengameart.org/content/amb-rain-loop-2) (70 s slice, low-passed) | kresiek-the-furry |
| `rain_window.ogg` | [Rain on window loop](https://opengameart.org/content/rain-on-window-loop) | alxl |
| `rain_gutter.ogg` | [Rain gutter loop](https://opengameart.org/content/rain-gutter-loop) | ogrebane |
| `wind.ogg` | [Windy ambient noise](https://opengameart.org/content/windy-ambient-noise) (95 s slice) | some-weirdo |
| `traffic_distant.ogg` | [100 CC0 SFX #2](https://opengameart.org/content/100-cc0-sfx-2), `loop_highway` (low-passed) | rubberduck |
| `thunder_1.ogg` | [Rain, long thunder](https://opengameart.org/content/rain-long-thunder) (thunder section) | wuxiascrub |
| `thunder_2.ogg` | [100 CC0 SFX #2](https://opengameart.org/content/100-cc0-sfx-2), `thunder_01` | rubberduck |
| `thunder_3.ogg` | [Low rumbling](https://opengameart.org/content/low-rumbling) (low-passed) | musheran |
| `tree_creak.ogg` | [Tree creaking](https://opengameart.org/content/tree-creaking) | antumdeluge |
| `lamp_buzz.ogg` | [Electric buzz](https://opengameart.org/content/electric-buzz) | themightyglider |
| `mouse_click.ogg` | [Mouse click](https://opengameart.org/content/mouse-click) | lfa |

## Radio music (CC0 / public domain, from OpenGameArt.org)

Played through a "transistor radio" filter in `tools/build_audio.py`.

| File | Track | Author |
|---|---|---|
| `radio_1.ogg` | [Midnight Drive](https://opengameart.org/content/midnight-drive) | congusbongus |
| `radio_2.ogg` | [Jazz (Saxophone)](https://opengameart.org/content/jazz-saxaphone) | pro-sensory |
| `radio_3.ogg` | [Dimly Lit](https://opengameart.org/content/dimly-lit) | iamoneabe |
| `radio_4.ogg` | [Slow Stride](https://opengameart.org/content/slow-stride) | isaiah658 |
| `radio_5.ogg` | [Jazz Slower](https://opengameart.org/content/jazz-slower) | pro-sensory |
| `radio_6.ogg` | [Cool City](https://opengameart.org/content/cool-city) | mintodog |
| `radio_7.ogg` | [Elevator Music](https://opengameart.org/content/elevator-music) | pro-sensory |

## Synthesised sounds (made for this game, see `tools/build_audio.py`)

`fluorescent_hum.ogg`, `crt_hum.ogg`, `clock_tick.ogg`, `light_flicker.ogg`,
`radio_hiss.ogg`, `radio_click.ogg`, `radio_static.ogg`

Desktop computer sounds (`tools/build_desktop_audio.py`): `bios.ogg`, `hdd.ogg`, `chime.ogg`,
`click2.ogg`, `ding.ogg`, `dialup.ogg`

## Rebuilding

```bash
tools/fetch_audio.sh /tmp/darkpark_raw
python3 tools/build_audio.py /tmp/darkpark_raw /tmp/darkpark_raw/music
```
