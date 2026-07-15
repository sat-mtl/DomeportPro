VARYING vec3 pos;
VARYING vec2 texcoord;

void MAIN()
{
    pos = VERTEX;
    texcoord = UV0 * 50.0;
    POSITION = MODELVIEWPROJECTION_MATRIX * vec4(pos, 1.0);
}
