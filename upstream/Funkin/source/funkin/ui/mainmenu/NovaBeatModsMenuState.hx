package funkin.ui.mainmenu;

import flixel.FlxG;
import flixel.FlxSprite;
import funkin.audio.FunkinSound;
import funkin.graphics.FunkinCamera;
import funkin.Preferences;
import funkin.graphics.shaders.HSVShader;
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
  var novaBeatStyle:Bool = false;

  override function create():Void
  {
    FlxG.keys.enabled = true;
    FlxG.cameras.reset(new FunkinCamera('novaBeatMods'));
    super.create();

    var novaBeatStyle:Bool = Preferences.menuStyle == "NovaBeat";
    this.novaBeatStyle = novaBeatStyle;
    var background:FlxSprite = new FlxSprite().loadGraphic(Paths.image(novaBeatStyle ? 'novabeat/menu-background' : 'menuBG'));
    menuBackground = background;
    if (novaBeatStyle)
    {
      var scale:Float = Math.max(FlxG.width / background.width, FlxG.height / background.height);
      background.scale.set(scale, scale);
    }
    else
    {
      background.shader = new HSVShader(-0.6, 0.9, 3.6);
      background.setGraphicSize(Std.int(FlxG.width * 1.1));
    }
    background.updateHitbox();
    background.screenCenter();
    background.scrollFactor.set();
    add(background);

    var dimmer:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, novaBeatStyle ? 0xA9040A1A : 0x78000000);
    backgroundDimmer = dimmer;
    dimmer.scrollFactor.set();
    add(dimmer);

    if (!novaBeatStyle) Cursor.show();
    FunkinSound.playMusic(novaBeatStyle ? 'novabeat-menu' : 'freakyMenu', {
      overrideExisting: true,
      restartTrack: false,
      persist: true,
      mapTimeChanges: false
    });

    modPage = new ModMenu();
    modPage.onExit.add(goBack);
    add(modPage);
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (menuBackground != null)
    {
      if (novaBeatStyle)
      {
        var scale:Float = Math.max(width / Math.max(1, menuBackground.frameWidth), height / Math.max(1, menuBackground.frameHeight));
        menuBackground.scale.set(scale, scale);
      }
      else
      {
        menuBackground.setGraphicSize(Std.int(width * 1.1));
      }
      menuBackground.updateHitbox();
      menuBackground.screenCenter();
    }
    if (backgroundDimmer != null)
    {
      backgroundDimmer.makeGraphic(width, height, novaBeatStyle ? 0xA9040A1A : 0x78000000);
      backgroundDimmer.setPosition(0, 0);
    }
  }

  function goBack():Void
  {
    if (Preferences.menuStyle == "NovaBeat")
      FlxG.switchState(() -> new NovaBeatMainMenuState());
    else
      FlxG.switchState(() -> new MainMenuState());
  }
}
