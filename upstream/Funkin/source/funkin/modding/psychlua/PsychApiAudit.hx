package funkin.modding.psychlua;

import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.util.FileUtil;

/**
 * Finds Psych API calls that mod scripts make but the compatibility layer does
 * not implement.
 *
 * Lua only tells you "attempt to call a nil value" and then aborts the rest of
 * the script, which hides every later problem behind the first one. Scanning the
 * script text against the registered API surface instead gives a complete list
 * in one pass. Results are written to logs/psych-missing-api.log and shown
 * briefly on screen so a missing function is visible rather than mysterious.
 */
class PsychApiAudit
{
  /** Lua keywords and standard library entry points that are never API gaps. */
  static var NON_API:Map<String, Bool> = [
    "function" => true, "if" => true, "elseif" => true, "else" => true, "while" => true, "return" => true,
    "pairs" => true, "ipairs" => true, "tonumber" => true, "tostring" => true, "type" => true,
    "print" => true, "string" => true, "table" => true, "math" => true, "os" => true, "io" => true,
    "setmetatable" => true, "getmetatable" => true, "pcall" => true, "xpcall" => true, "error" => true,
    "assert" => true, "unpack" => true, "select" => true, "rawget" => true, "rawset" => true,
    "next" => true, "require" => true, "coroutine" => true, "debug" => true, "utf8" => true,
    // Keywords that can sit directly before a parenthesis, e.g. `a or (b)`.
    "or" => true, "and" => true, "not" => true, "then" => true, "do" => true, "end" => true,
    "for" => true, "in" => true, "local" => true, "repeat" => true, "until" => true,
    "break" => true, "nil" => true, "true" => true, "false" => true
  ];

  /** Last audit result, for callers that want to inspect it. */
  public static var missing:Array<String> = [];

  /**
   * A plain function call, not a method call. `string.sub(` and `math.floor(`
   * are Lua standard library usage, and reporting them as missing Psych API
   * only buried the real gaps.
   */
  static var CALL_PATTERN:EReg = ~/(^|[^.:A-Za-z0-9_])([A-Za-z_][A-Za-z0-9_]*)\s*\(/g;
  static var DEFINE_PATTERN:EReg = ~/function\s+([A-Za-z_][A-Za-z0-9_]*)/g;
  /** Lua long strings; HScript lives inside these and is not Lua. */
  static var LONG_STRING:EReg = ~/\[\[[\s\S]*?\]\]/g;
  /** Single and double quoted literals. */
  static var STRING_LITERAL:EReg = ~/"([^"\\]|\\[\s\S])*"|'([^'\\]|\\[\s\S])*'/g;

  /**
   * Audit every script about to run and report the gaps once.
   * @param state The gameplay state the scripts belong to.
   * @param sources The script sources resolved for this song.
   */
  public static function audit(state:FlxState, sources:Array<Dynamic>):Void
  {
    if (sources == null || sources.length == 0) return;

    var known:Map<String, Bool> = [];
    for (name in PsychGameplayApi.getKnownApiNames())
      known.set(name, true);

    var found:Array<String> = [];
    var perScript:Array<String> = [];

    for (source in sources)
    {
      if (source == null) continue;
      var code:Dynamic = Reflect.field(source, "source");
      var pathValue:Dynamic = Reflect.field(source, "path");
      if (!Std.isOfType(code, String)) continue;
      var text:String = cast code;
      var path:String = Std.isOfType(pathValue, String) ? cast pathValue : "(script)";
      if (!StringTools.endsWith(path.toLowerCase(), ".lua")) continue;

      // Strip string literals first. runHaxeCode([[...]]) snippets are HScript,
      // and scanning them reported FlxBar, floor and setFloat as missing Lua API.
      var scanned:String = LONG_STRING.replace(text, " ");
      scanned = STRING_LITERAL.replace(scanned, " ");

      // Names the script defines itself are local functions, not API gaps.
      var local:Map<String, Bool> = [];
      var position:Int = 0;
      while (DEFINE_PATTERN.matchSub(scanned, position))
      {
        local.set(DEFINE_PATTERN.matched(1), true);
        var where = DEFINE_PATTERN.matchedPos();
        position = where.pos + where.len;
      }

      position = 0;
      while (CALL_PATTERN.matchSub(scanned, position))
      {
        var name:String = CALL_PATTERN.matched(2);
        var matchPosition = CALL_PATTERN.matchedPos();
        position = matchPosition.pos + matchPosition.len;

        if (known.exists(name) || NON_API.exists(name) || local.exists(name)) continue;
        if (found.indexOf(name) >= 0) continue;
        found.push(name);
        perScript.push(path.split("/").pop() + ": " + name);
      }
    }

    missing = found;
    if (found.length == 0) return;

    var summary:String = found.length + " unimplemented Psych API call(s): " + found.join(", ");
    trace("[Psych API Audit] " + summary);

    #if sys
    try
    {
      var details:String = summary + "\n";
      for (line in perScript) details += "  " + line + "\n";
      FileUtil.appendStringToPath("logs/psych-missing-api.log", details);
    }
    catch (error:Dynamic) {}
    #end

    showNotice(state, summary);
  }

  /** Small on-screen list so a missing function is visible during play. */
  static function showNotice(state:FlxState, summary:String):Void
  {
    if (state == null || summary == null) return;
    try
    {
      var label:FlxText = new FlxText(8, 8, 900, summary, 12);
      // Keep to members this Flixel build definitely has. Its text alignment and
      // border enums do not resolve as imports here, and it has no text
      // background, so the notice is a plain coloured label; the log file is the
      // authoritative record.
      label.color = FlxColor.YELLOW;
      label.scrollFactor.set(0, 0);
      state.add(label);

      new FlxTimer().start(12, function(_):Void
      {
        if (label != null && label.exists) label.destroy();
      });
    }
    catch (error:Dynamic) {}
  }
}
