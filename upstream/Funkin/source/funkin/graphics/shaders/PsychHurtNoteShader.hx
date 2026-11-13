package funkin.graphics.shaders;

import flixel.system.FlxAssets.FlxShader;

/**
 * Psych Engine 0.7.3's built-in Hurt Note palette.
 *
 * Psych 0.7.3 recolors the normal note texture with an RGB palette; it does
 * not load a separate HURTNOTE_assets sheet for its built-in Hurt Note.
 */
class PsychHurtNoteShader extends FlxShader
{
  static var cached:Null<PsychHurtNoteShader> = null;

  public static function shared():PsychHurtNoteShader
  {
    if (cached == null) cached = new PsychHurtNoteShader();
    return cached;
  }

  @:glFragmentHeader('
    #pragma header

    uniform vec3 r;
    uniform vec3 g;
    uniform vec3 b;
    uniform float mult;

    vec4 flixel_texture2DCustom(sampler2D bitmapTexture, vec2 coordinate)
    {
      vec4 color = flixel_texture2D(bitmapTexture, coordinate);
      if (!hasTransform || color.a == 0.0 || mult == 0.0)
      {
        return color;
      }

      vec4 newColor = color;
      newColor.rgb = min(color.r * r + color.g * g + color.b * b, vec3(1.0));
      newColor.a = color.a;
      color = mix(color, newColor, mult);

      if (color.a > 0.0)
      {
        return vec4(color.rgb, color.a);
      }
      return vec4(0.0, 0.0, 0.0, 0.0);
    }
  ')

  @:glFragmentSource('
    #pragma header

    void main()
    {
      gl_FragColor = flixel_texture2DCustom(bitmap, openfl_TextureCoordv);
    }
  ')

  public function new()
  {
    super();

    // Psych Engine 0.7.3 Note.set_noteType("Hurt Note") palette.
    r.value = [16.0 / 255.0, 16.0 / 255.0, 16.0 / 255.0];
    g.value = [1.0, 0.0, 0.0];
    b.value = [153.0 / 255.0, 0.0, 34.0 / 255.0];
    mult.value = [1.0];
  }
}
