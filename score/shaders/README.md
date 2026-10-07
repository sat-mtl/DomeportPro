# Projection shaders

Source of truth for the ISF projection shaders.

score stores an ISF Shader process with its source **inlined** in the process's
`"Fragment"` string, and `score/app.score` is self-contained on purpose (no
`"Root"` key, so nothing is loaded from disk at runtime). That makes the shaders
unreviewable in the document — they are `\n`-escaped JSON strings — so they live
here as well. **These files are not loaded at runtime:** a shader only takes
effect once its text is copied into the matching `"Fragment"` in `app.score`, and
when a shader here changes that copy has to be redone.

Currently wired into `app.score`: `equirectangular_to_domemaster` (inline, with
the `IMG_NORM_PIXEL` fix applied). `domemaster_to_equirectangular.fs` is
validated but **not yet wired in** — it is the building block for the planned
format-conversion tab.

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
which is exactly how it survived: it reached production and was worked around in
`rotate_zoom` rather than fixed, until the dome was finally measured under
Vulkan. Since `environment`/`environment-pro` pin `QSG_RHI_BACKEND=vulkan` on
Linux and Windows, Vulkan is the default path for most users.

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
