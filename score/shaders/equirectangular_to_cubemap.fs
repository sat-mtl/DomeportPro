/*{
    "DESCRIPTION": "Converts an equirectangular image to a cubemap atlas (horizontal strip, vertical cross or horizontal cross). Face order is +X -X +Y -Y +Z -Z. Areas of the atlas that belong to no face are left transparent.",
    "CREDIT": "Edu Meneses + AI Assistant (Gemini), adapted for Domeport Pro",
    "CATEGORIES": [
        "UTILITY",
        "FORMAT-CONVERTER",
        "3D"
    ],
    "INPUTS": [
        { "NAME": "equirectangularImage", "TYPE": "image", "LABEL": "Equirectangular Image" },
        {
            "NAME": "layoutType",
            "LABEL": "Output Atlas Layout",
            "TYPE": "long",
            "VALUES": [0, 1, 2],
            "LABELS": ["Horizontal Strip (6x1)", "Vertical Cross (3x4)", "Horizontal Cross (4x3)"],
            "DEFAULT": 0
        }
    ]
}*/

// Adapted from the score user library's equirectangular_to_cubemap. Two changes,
// both load-bearing here:
//
//  1. The per-face rotation inputs are dropped. They all defaulted to 0, and a
//     format converter that silently rotates individual faces is a footgun; it
//     also keeps this process to two ports.
//
//  2. The equirectangular V convention is flipped to match
//     equirectangular_to_domemaster, which is what the rest of this document
//     uses: v = 0.5 - lat/PI, north pole at v = 0. The library version samples
//     v = lat/PI + 0.5, the opposite. Chaining the two as they ship would have
//     produced a vertically mirrored cubemap -- and nothing upstream would have
//     said so, because each shader is self-consistent.

const float PI = 3.141592653589793;
const float TWO_PI = 2.0 * PI;

void main()
{
    vec2 atlasUV = isf_FragNormCoord;

    float cell_w_norm, cell_h_norm;
    if (layoutType == 0) {           // Horizontal Strip (6w x 1h)
        cell_w_norm = 1.0 / 6.0; cell_h_norm = 1.0;
    } else if (layoutType == 1) {    // Vertical Cross (3w x 4h)
        cell_w_norm = 1.0 / 3.0; cell_h_norm = 1.0 / 4.0;
    } else {                         // Horizontal Cross (4w x 3h)
        cell_w_norm = 1.0 / 4.0; cell_h_norm = 1.0 / 3.0;
    }

    // Face IDs: 0=+X, 1=-X, 2=+Y, 3=-Y, 4=+Z, 5=-Z. -1 = blank atlas cell.
    int faceID = -1;
    vec2 local_face_uv = vec2(0.0);

    if (layoutType == 0) {
        faceID = int(floor(atlasUV.x / cell_w_norm));
        local_face_uv.x = fract(atlasUV.x / cell_w_norm);
        local_face_uv.y = atlasUV.y;
    } else if (layoutType == 1) {
        vec2 grid_pos = floor(atlasUV / vec2(cell_w_norm, cell_h_norm));
        if (grid_pos.x == 2.0 && grid_pos.y == 2.0) faceID = 0;
        else if (grid_pos.x == 0.0 && grid_pos.y == 2.0) faceID = 1;
        else if (grid_pos.x == 1.0 && grid_pos.y == 3.0) faceID = 2;
        else if (grid_pos.x == 1.0 && grid_pos.y == 1.0) faceID = 3;
        else if (grid_pos.x == 1.0 && grid_pos.y == 2.0) faceID = 4;
        else if (grid_pos.x == 1.0 && grid_pos.y == 0.0) faceID = 5;

        if (faceID != -1) {
            local_face_uv.x = (atlasUV.x - grid_pos.x * cell_w_norm) / cell_w_norm;
            local_face_uv.y = (atlasUV.y - grid_pos.y * cell_h_norm) / cell_h_norm;
        }
    } else {
        vec2 grid_pos = floor(atlasUV / vec2(cell_w_norm, cell_h_norm));
        if (grid_pos.x == 2.0 && grid_pos.y == 1.0) faceID = 0;
        else if (grid_pos.x == 0.0 && grid_pos.y == 1.0) faceID = 1;
        else if (grid_pos.x == 1.0 && grid_pos.y == 2.0) faceID = 2;
        else if (grid_pos.x == 1.0 && grid_pos.y == 0.0) faceID = 3;
        else if (grid_pos.x == 1.0 && grid_pos.y == 1.0) faceID = 4;
        else if (grid_pos.x == 3.0 && grid_pos.y == 1.0) faceID = 5;

        if (faceID != -1) {
            local_face_uv.x = (atlasUV.x - grid_pos.x * cell_w_norm) / cell_w_norm;
            local_face_uv.y = (atlasUV.y - grid_pos.y * cell_h_norm) / cell_h_norm;
        }
    }

    if (faceID == -1) {
        isf_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }

    // Flip Y to match the coordinate system the direction vectors below assume.
    local_face_uv.y = 1.0 - local_face_uv.y;

    vec2 face_coords = local_face_uv * 2.0 - 1.0;

    vec3 dir;
    if (faceID == 0)      dir = normalize(vec3( 1.0, -face_coords.y, -face_coords.x)); // +X
    else if (faceID == 1) dir = normalize(vec3(-1.0, -face_coords.y,  face_coords.x)); // -X
    else if (faceID == 2) dir = normalize(vec3( face_coords.x,  1.0,  face_coords.y)); // +Y
    else if (faceID == 3) dir = normalize(vec3( face_coords.x, -1.0, -face_coords.y)); // -Y
    else if (faceID == 4) dir = normalize(vec3( face_coords.x, -face_coords.y,  1.0)); // +Z
    else                  dir = normalize(vec3(-face_coords.x, -face_coords.y, -1.0)); // -Z

    float lon = atan(dir.x, dir.z);
    float lat = asin(dir.y);

    vec2 equirectUV;
    equirectUV.x = lon / TWO_PI + 0.5;
    equirectUV.y = 0.5 - lat / PI;   // see note 2 above

    // IMG_NORM_PIXEL, never a bare texture(): the SPIRV texcoord fixup lives
    // only inside these macros, so a raw sample is upside down under Vulkan.
    isf_FragColor = IMG_NORM_PIXEL(equirectangularImage, equirectUV);
}
