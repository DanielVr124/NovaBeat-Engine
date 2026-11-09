package funkin.graphics.shaders;

import flixel.graphics.frames.FlxFrame;
import flixel.system.FlxAssets.FlxShader;

/**
 * NovaBeat title transition: an organic dissolve that advances inward from
 * every outer edge. Frame UV bounds are refreshed for Sparrow-atlas frames.
 */
class NovaBeatEdgeDissolveShader extends FlxShader
{
  public var progress(default, set):Float = 0;

  function set_progress(value:Float):Float
  {
    progress = Math.max(0, Math.min(1, value));
    edgeProgress.value = [progress];
    return value;
  }

  public function updateFrame(frame:FlxFrame):Void
  {
    if (frame == null || frame.uv == null)
    {
      edgeFrameBounds.value = [0, 0, 1, 1];
      return;
    }

    edgeFrameBounds.value = [
      frame.uv.left,
      frame.uv.top,
      frame.uv.right,
      frame.uv.bottom
    ];
  }

  @:glFragmentSource('
    #pragma header

    uniform float edgeProgress;
    uniform vec4 edgeFrameBounds;

    float hash21(vec2 p)
    {
      p = fract(p * vec2(123.34, 456.21));
      p += dot(p, p + 45.32);
      return fract(p.x * p.y);
    }

    float valueNoise(vec2 p)
    {
      vec2 cell = floor(p);
      vec2 local = fract(p);
      local = local * local * (3.0 - 2.0 * local);

      float a = hash21(cell);
      float b = hash21(cell + vec2(1.0, 0.0));
      float c = hash21(cell + vec2(0.0, 1.0));
      float d = hash21(cell + vec2(1.0, 1.0));

      return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
    }

    void main()
    {
      vec2 frameSize = max(edgeFrameBounds.zw - edgeFrameBounds.xy, vec2(0.000001));
      vec2 uv = clamp((openfl_TextureCoordv - edgeFrameBounds.xy) / frameSize, 0.0, 1.0);
      vec4 color = flixel_texture2D(bitmap, openfl_TextureCoordv);

      // The distance field is zero at all four edges and reaches its maximum
      // at the center, so the middle is always the final region to disappear.
      float edgeDistance = 2.0 * min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));

      // Low-frequency noise breaks up the moving boundary. It changes the
      // shape of the dissolve front, not the direction or overall progression.
      float breakup = (valueNoise(uv * 26.0) - 0.5) * 0.14;
      float feather = 0.035;
      float threshold = mix(-feather, 1.12, edgeProgress) + breakup * smoothstep(0.0, 0.18, edgeProgress);
      float visibility = 1.0 - smoothstep(threshold, threshold + feather, edgeDistance);

      // At completion force every pixel transparent, including the exact center.
      visibility *= 1.0 - step(0.9999, edgeProgress);

      gl_FragColor = vec4(color.rgb, color.a * visibility);
    }
  ')

  public function new()
  {
    super();
    edgeProgress.value = [0];
    edgeFrameBounds.value = [0, 0, 1, 1];
  }
}
