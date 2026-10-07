/*{
    "DESCRIPTION": "Projects a domemaster (azimuthal-equidistant fisheye) image back to equirectangular. Exact inverse of equirectangular_to_domemaster: same Euler convention, same input FOV meaning, same horizontal-flip semantics. Directions outside the dome's FOV are left transparent.",
    "CREDIT": "SAT / Domeport Pro",
    "CATEGORIES": [
        "GENERATOR",
        "3D",
        "DOME",
        "PANORAMIC"
    ],
    "INPUTS": [
        { "NAME": "domemasterImage", "TYPE": "image", "LABEL": "Domemaster Input" },
        {
          "NAME" :"XYZrotate",
          "TYPE" : "point3D",
          "DEFAULT" : [0.5, 0.5, 0.5],
          "MAX" : [1.0, 1.0, 1.0],
          "MIN" : [0.0, 0.0, 0.0]
        },
        {
            "NAME": "domemaster_input_fov_degrees",
            "LABEL": "Domemaster Input FOV (degrees)",
            "TYPE": "float",
            "DEFAULT": 180.0,
            "MIN": 1.0,
            "MAX": 360.0
        },
        {
            "NAME": "flipHorizontal",
            "LABEL": "Flip Horizontally (Ext. Surface)",
            "TYPE": "bool",
            "DEFAULT": false
        }
    ]
}*/

#define M_PI 3.14159265359

// Same construction as equirectangular_to_domemaster's, so that transposing it
// below is exactly the inverse rotation rather than an approximation of one.
mat3 makeRotationMatrix(vec3 a) // a = (yaw, pitch, roll)
{
    mat3 my = mat3(cos(a.x), 0, sin(a.x),  0, 1, 0,  -sin(a.x), 0, cos(a.x)); // Yaw
    mat3 mx = mat3(1, 0, 0,  0, cos(a.y), -sin(a.y),  0, sin(a.y), cos(a.y)); // Pitch
    mat3 mz = mat3(cos(a.z), -sin(a.z), 0,  sin(a.z), cos(a.z), 0,  0,0,1);   // Roll

    return my * mx * mz;
}

void main()
{
    // Output pixel -> direction on the sphere. Mirrors the forward shader's
    // u = longitude/2pi + 0.5 and v = 0.5 - latitude/pi.
    vec2 equirect_uv = isf_FragNormCoord;
    float longitude = (equirect_uv.x - 0.5) * 2.0 * M_PI;
    float latitude  = (0.5 - equirect_uv.y) * M_PI;

    float cos_lat = cos(latitude);
    vec3 ray_dir_world = vec3(
        sin(longitude) * cos_lat,
        sin(latitude),
        cos(longitude) * cos_lat);

    float roll_angle  = (XYZrotate.z - 0.5) * 2.0 * M_PI;
    float yaw_angle   = XYZrotate.x * 2.0 * M_PI;
    float pitch_angle = XYZrotate.y * 2.0 * M_PI;

    mat3 camera_to_world_rotation_matrix
        = makeRotationMatrix(vec3(yaw_angle, pitch_angle, roll_angle));

    // The forward shader applies camera_to_world; a rotation matrix is
    // orthonormal, so its transpose is its inverse and no inverse() is needed
    // (inverse() on a mat3 is not available in every profile score bakes to).
    vec3 ray_dir_view = transpose(camera_to_world_rotation_matrix) * ray_dir_world;

    float fisheye_half_fov_rad = (domemaster_input_fov_degrees / 2.0) * (M_PI / 180.0);
    float ray_polar_angle_view = acos(clamp(ray_dir_view.z, -1.0, 1.0));

    // Outside the captured cap there is no source pixel; invent nothing.
    float dist_from_center = ray_polar_angle_view / fisheye_half_fov_rad;
    if (dist_from_center > 1.0) {
        isf_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }

    float ray_azimuth_angle_view = atan(ray_dir_view.y, ray_dir_view.x);
    vec2 p_centered = dist_from_center
                    * vec2(cos(ray_azimuth_angle_view), sin(ray_azimuth_angle_view));

    // Undo the forward shader's aspect correction, against the SOURCE image's
    // aspect rather than RENDERSIZE: here RENDERSIZE is the equirect output.
    vec2 src_size = vec2(IMG_SIZE(domemasterImage));
    float source_aspect = src_size.x / src_size.y;
    if (source_aspect > 1.0) {
        p_centered.x /= source_aspect;
    } else {
        p_centered.y *= source_aspect;
    }

    if (flipHorizontal) {
        p_centered.x = -p_centered.x;
    }

    vec2 domemaster_uv = p_centered * 0.5 + 0.5;

    // IMG_NORM_PIXEL, never a bare texture(): the SPIRV texcoord fixup lives
    // only inside these macros, so a raw sample is upside down under Vulkan.
    isf_FragColor = IMG_NORM_PIXEL(domemasterImage, domemaster_uv);
}
