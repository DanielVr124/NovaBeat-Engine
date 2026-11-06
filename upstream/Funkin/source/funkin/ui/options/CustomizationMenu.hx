package funkin.ui.options;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import funkin.graphics.FunkinCamera;
import funkin.graphics.FunkinSprite;
import funkin.Preferences;
import funkin.ui.AtlasText.AtlasFont;
import funkin.ui.Page;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
#if FEATURE_TOUCH_CONTROLS
import funkin.mobile.ui.FunkinBackButton;
#end

/**
 * Top-level customization category selector.
 *
 * Keep this page separate from individual style settings so other menu
 * presentations can add their own customization pages without crowding Options.
 */
class CustomizationMenu extends Page<OptionsState.OptionsMenuPageName>
{
  var items:TextMenuList;
  var menuCamera:FlxCamera;
  var hudCamera:FlxCamera;
  var camFollow:FlxObject;
  var itemDesc:FlxText;
  var itemDescBox:FunkinSprite;

  public function new()
  {
    super();

    menuCamera = new FunkinCamera('customizationMenu');
    FlxG.cameras.add(menuCamera, false);
    menuCamera.bgColor = 0x0;
    hudCamera = new FlxCamera();
    FlxG.cameras.add(hudCamera, false);
    hudCamera.bgColor = 0x0;
    camera = menuCamera;

    NovaBeatOptionsChrome.apply(this, 'CUSTOMIZATION', menuCamera);

    items = new TextMenuList();
    add(items);

    var itemY:Float = Preferences.menuStyle == "NovaBeat" ? 112 : 30;
    var item:TextMenuItem = items.createItem(0, itemY, 'NOVABEAT MENU', AtlasFont.BOLD, function()
    {
      codex.switchPage(MenuCustomization);
    });
    item.screenCenter(X);

    var performanceItem:TextMenuItem = items.createItem(0, itemY + 112, 'PERFORMANCE', AtlasFont.BOLD, function()
    {
      codex.switchPage(Performance);
    });
    performanceItem.screenCenter(X);

    itemDescBox = new FunkinSprite();
    itemDescBox.makeSolidColor(1, 1, Preferences.menuStyle == "NovaBeat" ? 0xFF0D1935 : FlxColor.BLACK);
    itemDescBox.alpha = Preferences.menuStyle == "NovaBeat" ? 0.9 : 0.6;
    itemDescBox.cameras = [hudCamera];
    add(itemDescBox);

    itemDesc = new FlxText(0, 0, 1180, null, 32);
    itemDesc.cameras = [hudCamera];
    itemDesc.setFormat(Paths.font('vcr.ttf'), 32,
      Preferences.menuStyle == "NovaBeat" ? 0xFF48E7FF : FlxColor.WHITE,
      FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    itemDesc.borderSize = 3;
    itemDesc.text = 'Customize the NovaBeat menu colours, background, equalizer, layout, and animations.';
    itemDesc.screenCenter();
    itemDesc.y += 270;
    itemDescBox.setPosition(itemDesc.x - 10, itemDesc.y - 10);
    itemDescBox.setGraphicSize(Std.int(itemDesc.width + 20), Std.int(itemDesc.height + 25));
    itemDescBox.updateHitbox();
    add(itemDesc);

    items.onChange.add(function(selected:TextMenuItem)
    {
      itemDesc.text = items.selectedIndex == 1
        ? 'Tune visual effects and background rendering for lower-powered devices without changing rhythm timing.'
        : 'Customize the NovaBeat menu colours, background, equalizer, layout, and animations.';
    });

    camFollow = new FlxObject(FlxG.width / 2, itemY, 140, 70);
    menuCamera.follow(camFollow, null, 0.085);
    menuCamera.deadzone.set(0, 160, menuCamera.width, menuCamera.height - 320);
    menuCamera.minScrollY = 0;

    #if FEATURE_TOUCH_CONTROLS
    var backButton:FunkinBackButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, exit, 1.0);
    add(backButton);
    #end
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (items != null && items.selectedItem != null) camFollow.y = items.selectedItem.y;
  }

  override function destroy():Void
  {
    super.destroy();
    if (FlxG.cameras.list.contains(menuCamera)) FlxG.cameras.remove(menuCamera);
    if (FlxG.cameras.list.contains(hudCamera)) FlxG.cameras.remove(hudCamera);
  }
}
