package funkin.ui.options;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import funkin.graphics.FunkinCamera;
import funkin.graphics.FunkinSprite;
import funkin.util.DeviceUtil;
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
  var categoryItems:Array<TextMenuItem> = [];
  #if FEATURE_TOUCH_CONTROLS
  var responsiveBackButton:Null<FunkinBackButton> = null;
  #end

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

    items = new TextMenuList();
    // The category list is rendered through menuCamera. Assign that camera
    // directly to the list so MenuTypedList's mobile pointer hit-tests use
    // the same screen transform as the visible FNF-style entries.
    items.cameras = [menuCamera];
    items.acceptOnTouchSelection = DeviceUtil.isMobileBrowser;
    add(items);

    var itemY:Float = 30;
    var performanceItem:TextMenuItem = items.createItem(0, itemY, 'PERFORMANCE', AtlasFont.BOLD, function()
    {
      OptionsState.instance.openPerformanceCustomization();
    });
    performanceItem.screenCenter(X);
    performanceItem.cameras = [menuCamera];
    categoryItems.push(performanceItem);

    #if (mobile || FEATURE_TOUCH_CONTROLS)
    if (DeviceUtil.isMobileBrowser)
    {
      var mobileItem:TextMenuItem = items.createItem(0, itemY + 112, 'MOBILE', AtlasFont.BOLD, function()
    {
      OptionsState.instance.openMobileCustomization();
    });
    mobileItem.screenCenter(X);
    mobileItem.cameras = [menuCamera];
    categoryItems.push(mobileItem);
    }
    #end

    items.onChange.add(updateCategoryDescription);
    if (items.selectedItem != null) updateCategoryDescription(items.selectedItem);
    layoutFNFCategoryItems(FlxG.width, FlxG.height);

    itemDescBox = new FunkinSprite();
    itemDescBox.makeSolidColor(1, 1, FlxColor.BLACK);
    itemDescBox.alpha = 0.6;
    itemDescBox.cameras = [hudCamera];
    add(itemDescBox);

    itemDesc = new FlxText(0, 0, 1180, null, 32);
    itemDesc.cameras = [hudCamera];
    itemDesc.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE,
      FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    itemDesc.borderSize = 3;
    itemDesc.text = 'Adjust graphics and performance settings.';
    itemDesc.screenCenter();
    itemDesc.y += 270;
    itemDescBox.setPosition(itemDesc.x - 10, itemDesc.y - 10);
    itemDescBox.setGraphicSize(Std.int(itemDesc.width + 20), Std.int(itemDesc.height + 25));
    itemDescBox.updateHitbox();
    add(itemDesc);

    #if FEATURE_TOUCH_CONTROLS
    if (DeviceUtil.isMobileBrowser)
    {
      responsiveBackButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, exit, 1.0);
      add(responsiveBackButton);
    }
    #end
  }

  function updateCategoryDescription(selected:TextMenuItem):Void
  {
    if (itemDesc == null) return;
    var selectedIndex:Int = items == null ? 0 : items.selectedIndex;
    #if (mobile || FEATURE_TOUCH_CONTROLS)
    itemDesc.text = selectedIndex == 1
      ? 'Choose your mobile controls and screen orientation.'
      : 'Adjust graphics and performance settings.';
    #else
    itemDesc.text = 'Adjust graphics and performance settings.';
    #end
  }

  /**
   * Center the original FNF category entries as a single group in the
   * available menu area. All entries fit at once, so the camera must not
   * follow the selected row and pull the group toward the top edge.
   */
  function layoutFNFCategoryItems(width:Int, height:Int):Void
  {
    if (items == null || categoryItems.length == 0 || width <= 0 || height <= 0) return;

    var portrait:Bool = height > width * 1.12;
    // Keep the stock FNF left-column alignment, but center the complete short
    // category group vertically so it does not bunch up at the top of the page.
    var notch:Float = FullScreenScaleMode.gameNotchSize.x;
    var baseX:Float = portrait ? Math.max(18, notch + 18) : Math.max(24, notch + 120);
    var availableTop:Float = Math.max(58, height * 0.10);
    var availableBottom:Float = height * 0.68;
    var availableHeight:Float = Math.max(100, availableBottom - availableTop);
    var gap:Float = portrait ? Math.min(112, availableHeight / Math.max(1, categoryItems.length)) : 120;
    var rowHeight:Float = 0;

    for (item in categoryItems)
    {
      item.scale.set(portrait ? 0.86 : 1.0, portrait ? 0.86 : 1.0);
      // TextMenuItem uses a transparent 1x1 backing graphic but preserves a
      // label-sized hitbox. updateHitbox() would replace that custom hitbox
      // with the backing graphic's 1x1 dimensions, making these rows untappable.
      rowHeight = Math.max(rowHeight, item.height);
    }

    var groupHeight:Float = rowHeight + Math.max(0, categoryItems.length - 1) * gap;
    var top:Float = availableTop + Math.max(0, (availableHeight - groupHeight) * 0.5);

    for (index in 0...categoryItems.length)
    {
      var item:TextMenuItem = categoryItems[index];
      var selectedIndent:Float = index == items.selectedIndex ? (portrait ? 18 : 30) : 0;
      item.setPosition(baseX + selectedIndent, top + index * gap);
    }
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (width <= 0 || height <= 0) return;
    menuCamera.setSize(width, height);
    hudCamera.setSize(width, height);
    var portrait:Bool = height > width * 1.12;
    layoutFNFCategoryItems(width, height);
    if (itemDesc == null || itemDescBox == null) return;
    itemDesc.visible = true;
    itemDescBox.visible = true;
    itemDesc.setFormat(Paths.font('vcr.ttf'), portrait ? 18 : 32, FlxColor.WHITE,
      FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    itemDesc.fieldWidth = Math.max(160, width - (portrait ? 36 : 120));
    itemDesc.x = (width - itemDesc.fieldWidth) * 0.5;
    itemDesc.y = portrait ? height * 0.78 : height * 0.76;
    itemDescBox.setPosition(itemDesc.x - 10, itemDesc.y - 10);
    itemDescBox.setGraphicSize(Std.int(itemDesc.fieldWidth + 20), Std.int(itemDesc.height + 22));
    itemDescBox.updateHitbox();
    #if FEATURE_TOUCH_CONTROLS
    if (responsiveBackButton != null)
      responsiveBackButton.setPosition(width - responsiveBackButton.width - 18, height - responsiveBackButton.height - 18);
    #end
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    layoutFNFCategoryItems(FlxG.width, FlxG.height);
  }

  override function destroy():Void
  {
    super.destroy();
    if (FlxG.cameras.list.contains(menuCamera)) FlxG.cameras.remove(menuCamera);
    if (FlxG.cameras.list.contains(hudCamera)) FlxG.cameras.remove(hudCamera);
  }
}
