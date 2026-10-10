// SPDX-License-Identifier: AGPL-3.0-or-later
// © Société des arts technologiques
//
// Single source of truth for the video-OUTPUT (sink) device backends offered by
// the format-conversion tab. Pure data + helpers — no Score.* calls, mirroring
// qmlcomponents/io/InputBackends.js so the two read the same way.
//
// Protocol UUIDs read out of ossia/score, not copied from documentation:
//   NDI Out     07651c13-… score-addon-ndi/Ndi/OutputFactory.hpp:20
//   Spout Out   ddf45db7-… score-plugin-gfx/Gfx/Spout/SpoutOutput.hpp:17
//   Syphon Out  087d032d-… score-plugin-gfx/Gfx/Syphon/SyphonOutput.hpp:26
//
// The platform lists are ceilings, not preferences. Spout is a Windows
// Direct3D11 shared-texture protocol and is compiled only on Windows x86_64
// (score-plugin-gfx/CMakeLists.txt:24-26); Syphon is macOS IOSurface and is
// compiled only on APPLE (:45-54). They cannot be offered elsewhere because the
// protocol does not exist there — so the UI must hide them rather than present a
// sink that can never be created.
.pragma library

const DESCRIPTORS = {
    "NDI": {
        uuid: "07651c13-83de-48b8-a450-abe2891051e8",
        platforms: ["*"],
        nameLabel: "Stream name"
    },
    "Spout": {
        uuid: "ddf45db7-9eaf-453c-8fc0-86ccdf21677c",
        platforms: ["windows"],
        nameLabel: "Sender name"
    },
    "Syphon": {
        uuid: "087d032d-9a42-4bc9-b3df-ad9ba9e86c07",
        platforms: ["osx"],
        nameLabel: "Server name"
    }
}

function descriptor(name) {
    return DESCRIPTORS[name] || null
}

// The sinks that can exist on this platform, in a stable order. "None" is
// always first so the tab opens with no device running.
function available(platformOs) {
    const out = ["None"]
    for (const name of ["NDI", "Spout", "Syphon"]) {
        const d = DESCRIPTORS[name]
        if (d.platforms.indexOf("*") !== -1 || d.platforms.indexOf(platformOs) !== -1)
            out.push(name)
    }
    return out
}

// Settings for Gfx::SharedOutputSettings: the sink name plus the frame it
// publishes. Width/height are the conversion output's resolution, not the
// window's.
function makeSettings(name, width, height, rate) {
    return { "Path": name, "Width": width, "Height": height, "Rate": rate }
}
