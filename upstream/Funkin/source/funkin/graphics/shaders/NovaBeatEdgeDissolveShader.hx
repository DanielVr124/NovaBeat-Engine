package funkin.graphics.shaders;

import flixel.graphics.frames.FlxFrame;
import flixel.system.FlxAssets.FlxShader;

/**
 * NovaBeat title transition: dissolve a sprite inward from all four outer edges.
 * Frame UV bounds are refreshed for Sparrow-atlas animations so the mask stays
 * aligned with the currently displayed logo/prompt frame.
 */
class NovaBeatEdgeDissolveShader extends FlxShader
{
  public var progress(default, set):Float = 0;

  function set_progress(value:Float):Float
  {
    edgeProgress.value = [Math.max(0, Math.min(1, value))];
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

    void main()
    {
      vec2 frameSize = max(edgeFrameBounds.zw - edgeFrameBounds.xy, vec2(0.000001));
      vec2 uv = clamp((openfl_TextureCoordv - edgeFrameBounds.xy) / frameSize, 0.0, 1.0);
      vec4 color = flixel_texture2D(bitmap, openfl_TextureCoordv);

      // A normalized distance field keeps the dissolve moving inward from
      // every side at once; the soft band prevents a hard clipping edge.
      float edgeDistance = 2.0 * min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
      float feather = 0.075;
      float threshold = mix(-feather, 1.0, edgeProgress);
      float visibility = smoothstep(threshold, threshold + feather, edgeDistance);

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
