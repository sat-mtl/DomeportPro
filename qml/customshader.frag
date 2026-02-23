VARYING vec3 pos;
VARYING vec2 texcoord;

void MAIN()
{
    vec4 c = texture(tex, texcoord);
    FRAGCOLOR = c;
}
