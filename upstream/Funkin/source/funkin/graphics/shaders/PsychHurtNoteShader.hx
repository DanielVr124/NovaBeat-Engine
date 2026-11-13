package funkin.graphics.shaders;

import flixel.system.FlxAssets.FlxShader;

/**
 * Psych Engine 0.7.3's built-in Hurt Note palette.
 *
 * Psych 0.7.3 does not use HURTNOTE_assets by default; it recolors the normal
 * note texture by mapping its red, green, and blue channels to these colors.
 */
class PsychHurtNoteShader extends FlxShader
{
  static var cached:Null<PsychHurtNoteShader> = null;

  public static function shared():PsychHurtNoteShader
  {
    if (cached == null) cached = new PsychHurtNoteShader();
    return cached;
  }

  @:glFragmentSource('
    #pragma header

    uniform vec3 r;
    uniform vec3 g;
    uniform vec3 b;
    uniform float mult;

    vec4 psychHurtTexture(sampler2D bitmapTexture, vec2 coordinate)
    {
      vec4 color = flixel_texture2D(bitmapTexture, coordinate);
      if (!hasTransform || color.a == 0.0 || mult == 0.0)
      {
        return color;
      }

      vec3 remapped = min(color.r * r + color.g * g + color.b * b, vec3(1.0));
      return vec4(mix(color.rgb, remapped, mult), color.a);
    }

    void main()
    {
      gl_FragColor = psychHurtTexture(bitmap, openfl_TextureCoordv);
    }
  ')
  public function new()
  {
    super();

    // Values match Psych Engine 0.7.3 Note.set_noteType("Hurt Note").
    r.value = [16.0 / 255.0, 16.0 / 255.0, 16.0 / 255.0];
    g.value = [1.0, 0.0, 0.0];
    b.value = [153.0 / 255.0, 0.0, 34.0 / 255.0];
    mult.value = [1.0];
  }
}
