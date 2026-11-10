package funkin.ui.mainmenu;

import flixel.FlxG;
import flixel.FlxSprite;
import funkin.graphics.FunkinCamera;
import funkin.graphics.shaders.HSVShader;
import funkin.audio.FunkinSound;
import funkin.input.Cursor;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.MusicBeatState;
import funkin.ui.options.ModMenu;

/**
 * Standalone mod library screen. Mods are no longer nested inside Options;
 * returning from this screen always returns to the menu that launched it.
 */
class NovaBeatModsMenuState extends MusicBeatState
{
  var modPage:ModMenu;
  var menuBackground:Null<FlxSprite> = null;
  var backgroundDimmer:Null<FlxSprite> = null;

  override function create():Void
  {
    FlxG.keys.enabled = true;
    FlxG.cameras.reset(new FunkinCamera('modLibrary'));
    super.create();

    var background:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuBG'));
    menuBackground = background;
    background.shader = new HSVShader(-0.6, 0.9, 3.6);
    background.setGraphicSize(Std.int(FlxG.width * 1.1));
    background.updateHitbox();
    background.screenCenter();
    background.scrollFactor.set();
    add(background);

    var dimmer:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0x78000000);
    backgroundDimmer = dimmer;
    dimmer.scrollFactor.set();
    add(dimmer);

    FunkinSound.stopAllAudio(true, true);
    silenceMenuMusic();
    Cursor.hide();

    modPage = new ModMenu();
    modPage.onExit.add(goBack);
    add(modPage);
    silenceMenuMusic();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    // The previous menu theme can finish loading after the state switch.
    // Keep the music channel empty for the lifetime of this screen.
    silenceMenuMusic();
    Cursor.hide();
    FlxG.mouse.visible = false;
  }

  function silenceMenuMusic():Void
  {
    if (FlxG.sound.music == null) return;
    FlxG.sound.music.stop();
    FlxG.sound.music.kill();
    FlxG.sound.music = null;
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (menuBackground != null)
    {
      menuBackground.setGraphicSize(Std.int(width * 1.1));
      menuBackground.updateHitbox();
      menuBackground.screenCenter();
    }
    if (backgroundDimmer != null)
    {
      backgroundDimmer.makeGraphic(width, height, 0x78000000);
      backgroundDimmer.setPosition(0, 0);
    }
  }

  function goBack():Void
  {
    FlxG.switchState(() -> new MainMenuState());
  }
}
