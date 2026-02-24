VARYING vec3 pos;
VARYING vec2 texcoord;

void MAIN()
{
    vec2 texcoord_flip_h = texcoord * vec2(-1.0, 1.0);
    vec4 c = texture(tex, texcoord_flip_h);
    FRAGCOLOR = c;
}
