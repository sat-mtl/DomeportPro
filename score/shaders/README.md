# Projection shaders

Source of truth for the ISF projection shaders.

score stores an ISF Shader process with its source **inlined** in the process's
`"Fragment"` string, and `score/app.score` is self-contained on purpose (no
`"Root"` key, so nothing is loaded from disk at runtime). That makes the shaders
unreviewable in the document — they are `\n`-escaped JSON strings — so they live
here as well. **These files are not loaded at runtime:** a shader only takes
effect once its text is copied into the matching `"Fragment"` in `app.score`, and
when a shader here changes that copy has to be redone.

Wired into `app.score` today:

| process | shader |
|---|---|
| `equirectangular_to_domemaster` | the forward projection, with the `IMG_NORM_PIXEL` fix |
| `conv_dome_to_equi` | `domemaster_to_equirectangular.fs` |
| `conv_equi_to_cube` | `equirectangular_to_cubemap.fs` |
| `rotate_zoom` | the dome tap — see the note below |

`cubesides_to_domemaster.fs` is carried here fixed but is **not** wired into any
process; it is kept so the upstream defect is recorded against a corrected copy.

## Never call `texture()` directly

Use `IMG_NORM_PIXEL(sampler, uv)` (or `IMG_THIS_PIXEL`, `IMG_PIXEL`, `IMG_TEXEL`)
to read an input image. **A bare `texture(sampler, uv)` is upside down under
Vulkan.**

score applies its texture-coordinate fixup only inside those macros —
`score/src/plugins/score-plugin-gfx/3rdparty/libisf/src/isf.cpp:214-236` defines
`ISF_FIXUP_TEXCOORD`, and with it the `1.-y`, under `#if defined(QSHADER_SPIRV)`
and nowhere else:

| backend | `texture(t,uv)` | `IMG_NORM_PIXEL(t,uv)` | agree? |
|---|---|---|---|
| OpenGL (GLSL) | identity | identity | yes |
| **Vulkan (SPIRV)** | identity | **y-flipped** | **no** |
| D3D11/12 (HLSL) | identity | identity | yes |
| Metal (MSL) | identity | identity | yes |

So the defect is Vulkan-only, and it is invisible on the three other backends —
which is exactly how it survived until the dome was finally measured under
Vulkan. `environment.linux` / `environment-pro.linux` pin
`QSG_RHI_BACKEND=vulkan`, so Vulkan is the default path for Linux users;
Windows falls back to Qt's own default (D3D11) and macOS pins metal.

### `rotate_zoom`: the rule applies, but it did not always

`rotate_zoom` in `app.score` is the tap Qt Quick 3D samples as a
`Texture.sourceItem`, and that path used to be the one exemption from the rule
above: it had to use a bare `texture()`, because `PreviewNode::createRenderer`
handed both OpenGL and Vulkan the no-op `PreviewRenderer`, and the bare sampler
was what absorbed the resulting asymmetry. Measured then: substituting
`IMG_NORM_PIXEL` left OpenGL identical (RMSE 0) and mirrored Vulkan in azimuth
(RMSE **0.212**, horizon labels running `330 320 310 …` descending).

score now gives the preview's host texture one row order on every backend, which
**reverses that polarity**: the bare sampler is what mirrors the dome, and
`IMG_NORM_PIXEL` is correct. Measured on an RTX 5090 under Vulkan: the shipped
bare sampler reads azimuth-mirrored (`80 70 60 … 350 340` descending, mirrored
glyphs), and `IMG_NORM_PIXEL` restores it to master-correct (image mean 29.02),
with OpenGL unaffected in both cases.

So there is no exemption any more, and `rotate_zoom` follows the rule. The two
changes are **coupled**: this document's sampler and score's `PreviewNode` must
move together, or exactly one of the pair leaves the dome mirrored. The coupling
is Vulkan-only in both directions — `ISF_FIXUP_TEXCOORD` is `1. - y` only under
`QSHADER_SPIRV`, and the engine change only alters the row order for OpenGL and
Vulkan — so D3D11 and Metal see neither the defect nor the fix.

## Audit of the upstream fulldome set

These come from the score user library (`ossia/score-user-library`,
`Presets/GLSL_shaders/fulldome/`), which is **not** shipped inside the app — it
is a separately downloaded package. Anything used here must be copied in.

Checked against the rule above:

| shader | sampling | status |
|---|---|---|
| `equirectangular_to_domemaster.fs` | raw `texture()` ×1 | **defective upstream**; fixed in our `app.score` |
| `cubesides_to_domemaster.fs` | raw `texture()` ×6 | **defective upstream**; not used here yet |
| `equirectangular_to_cubemap.fs` | `IMG_NORM_PIXEL` | clean |
| `cubemap_to_equirectangular.fs` | `IMG_NORM_PIXEL` | clean |
| `cubemap.fs`, `image_to_equirectangular.fs`, `domemaster_mask.fs`, `half_cubesides_to_domemaster.fs`, `hexagonal_faces_to_domemaster.fs`, `Video_Mixer_dome.fs` | `IMG_NORM_PIXEL` | clean |

The two defective ones should be fixed upstream as well; the fix is the same
one-token substitution and is a no-op on OpenGL, D3D and Metal.

Also worth knowing before designing around them: score supports `samplerCube`
ISF inputs, but **nothing in this build can produce a cube texture** —
`score-plugin-threedim` and `score-plugin-avnd`, which own the cube-face
producers, are both in our `SCORE_DISABLE_PLUGINS` list. Cubemap work therefore
has to go through a 2D atlas (as `equirectangular_to_cubemap.fs` does) or six
separate 2D ports, never a cube sampler.

## `domemaster_to_equirectangular.fs`

Written for this release: the upstream set had **no** shader taking a domemaster
as a geometric input, so both "domemaster → anything" directions were missing.
It is the exact inverse of `equirectangular_to_domemaster` — same Euler
convention, same FOV meaning, same horizontal-flip semantics — which makes
equirectangular a hub that completes the matrix:

```
domemaster <-> equirectangular <-> cubemap (atlas)
```

Verified by round trip, on both backends: with
`equirect -> domemaster -> equirect -> domemaster` spliced into the document in
place of the single forward pass, the rendered dome is geometrically identical to
the direct conversion — horizon labels `100..260` ascending, upright, above the
tick line, elevation ladder `20,10,-10` downward, colour patches in the same
positions.

| backend | RMSE vs the direct conversion |
|---|---|
| OpenGL | 0.0212 |
| Vulkan | 0.0212 |

That is the blur of two extra resamples, not a geometric difference — a
geometric error on this scene measures ~0.3 — and the two backends agreeing to
four decimals is the point: the shader reads its input through `IMG_NORM_PIXEL`,
so it has no per-backend behaviour to get wrong. Metal and D3D take the same
`#else` arm of that macro as OpenGL, so they are covered by the OpenGL column.

Directions outside the dome's FOV cap have no source pixel and are left
transparent rather than clamped, so a 180° master does not smear its rim across
the bottom half of the equirect output.
