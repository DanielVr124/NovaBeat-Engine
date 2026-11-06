package funkin.ui;

import flixel.group.FlxGroup;
import flixel.FlxG;
import flixel.FlxSubState;
import flixel.util.FlxSignal;
import funkin.input.Controls;
import funkin.audio.FunkinSound;
import funkin.Preferences;

/**
 * A page in a menu system.
 *
 * You can use it on it's own, or handle it with a `Codex`
 */
class Page<T:PageName> extends FlxGroup
{
  public var onSwitch(default, null) = new FlxTypedSignal<T->Void>();
  public var onExit(default, null) = new FlxSignal();
  public var enabled(default, set) = true;
  public var canExit = true;
  public var codex:Codex<T>;
  var lastViewportWidth:Int = -1;
  var lastViewportHeight:Int = -1;

  var controls(get, never):Controls;

  inline function get_controls() return PlayerSettings.player1.controls;

  var subState:FlxSubState;

  inline function switchPage(name:T)
  {
    onSwitch.dispatch(name);
  }

  function exit()
  {
    onExit.dispatch();
  }

  public function new()
  {
    super();
    lastViewportWidth = FlxG.width;
    lastViewportHeight = FlxG.height;
    FlxG.signals.gameResized.add(onGameResized);
  }

  override function update(elapsed:Float)
  {
    super.update(elapsed);
    syncViewportLayout();

    if (enabled) updateEnabled(elapsed);
  }

  function onGameResized(width:Int, height:Int):Void
  {
    syncViewportLayout();
  }

  function syncViewportLayout():Void
  {
    var width:Int = FlxG.width;
    var height:Int = FlxG.height;
    if (width <= 0 || height <= 0 || (width == lastViewportWidth && height == lastViewportHeight)) return;

    lastViewportWidth = width;
    lastViewportHeight = height;
    onViewportResize(width, height);
  }

  public function onViewportResize(width:Int, height:Int):Void
  {
  }

  function updateEnabled(elapsed:Float)
  {
    if (canExit && controls.BACK_P)
    {
      exit();
      FunkinSound.playOnce(Paths.sound(Preferences.menuStyle == 'NovaBeat' ? 'novabeat/back' : 'cancelMenu'));
    }
  }

  function set_enabled(value:Bool)
  {
    return this.enabled = value;
  }

  function openPrompt(prompt:Prompt, onClose:Void->Void)
  {
    enabled = false;
    prompt.closeCallback = function()
    {
      enabled = true;
      if (onClose != null) onClose();
    }

    FlxG.state.openSubState(prompt);
  }

  override function destroy()
  {
    FlxG.signals.gameResized.remove(onGameResized);
    super.destroy();
    onSwitch.removeAll();
  }
}

/**
 * For you to fill in your own page name stuff, see OptionsState.hx and it's OptionsMenuPageName
 */
enum abstract PageName(String) from String to String
{
}
