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
import funkin.util.DeviceUtil;
import funkin.util.TouchUtil;
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
  var categoryLabels:Array<FlxText> = [];
  var novaBeatStyle:Bool = false;
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

    novaBeatStyle = Preferences.menuStyle == "NovaBeat";
    NovaBeatOptionsChrome.apply(this, 'CUSTOMIZATION', menuCamera);

    items = new TextMenuList();
    // The category list is rendered through menuCamera. Assign that camera
    // directly to the list so MenuTypedList's mobile pointer hit-tests use
    // the same screen transform as the visible FNF-style entries.
    items.cameras = [menuCamera];
    items.acceptOnTouchSelection = novaBeatStyle;
    add(items);

    var itemY:Float = novaBeatStyle ? 112 : 30;
    var item:TextMenuItem = items.createItem(0, itemY, 'NOVABEAT MENU', AtlasFont.BOLD, function()
    {
      codex.switchPage(MenuCustomization);
    });
    item.screenCenter(X);
    item.cameras = [menuCamera];
    categoryItems.push(item);
    if (novaBeatStyle) styleNovaBeatCategory(item, 'NOVABEAT MENU');

    var performanceItem:TextMenuItem = items.createItem(0, itemY + 112, 'PERFORMANCE', AtlasFont.BOLD, function()
    {
      codex.switchPage(Performance);
    });
    performanceItem.screenCenter(X);
    performanceItem.cameras = [menuCamera];
    categoryItems.push(performanceItem);
    if (novaBeatStyle) styleNovaBeatCategory(performanceItem, 'PERFORMANCE');

    #if (mobile || FEATURE_TOUCH_CONTROLS)
    var mobileItem:TextMenuItem = items.createItem(0, itemY + 224, 'MOBILE', AtlasFont.BOLD, function()
    {
      codex.switchPage(Mobile);
    });
    mobileItem.screenCenter(X);
    mobileItem.cameras = [menuCamera];
    categoryItems.push(mobileItem);
    if (novaBeatStyle) styleNovaBeatCategory(mobileItem, 'MOBILE');
    #end

    if (novaBeatStyle)
    {
      camFollow = new FlxObject(FlxG.width / 2, itemY, 140, 70);
      menuCamera.follow(camFollow, null, 0.085);
      menuCamera.deadzone.set(0, FlxG.height * 0.14, menuCamera.width, FlxG.height * 0.72);
      menuCamera.minScrollY = 0;
      layoutNovaBeatCategoryItems(FlxG.width, FlxG.height);
    }
    else
    {
      layoutFNFCategoryItems(FlxG.width, FlxG.height);
    }

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

    if (novaBeatStyle)
    {
      itemDesc.visible = false;
      itemDescBox.visible = false;
    }
    else
    {
      items.onChange.add(function(selected:TextMenuItem)
      {
        itemDesc.text = switch (items.selectedIndex)
        {
          case 1: 'Tune visual effects and background rendering for lower-powered devices without changing rhythm timing.';
          case 2: 'Configure device orientation and other mobile-specific behavior.';
          default: 'Customize the NovaBeat menu colours, background, equalizer, layout, and animations.';
        };
      });
    }


    #if FEATURE_TOUCH_CONTROLS
    if (DeviceUtil.isMobileBrowser)
    {
      responsiveBackButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, exit, 1.0);
      add(responsiveBackButton);
    }
    #end
  }

  /**
   * Center the original FNF category entries as a single group in the
   * available menu area. All entries fit at once, so the camera must not
   * follow the selected row and pull the group toward the top edge.
   */
  function layoutFNFCategoryItems(width:Int, height:Int):Void
  {
    if (categoryItems.length == 0 || width <= 0 || height <= 0) return;

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
      item.updateHitbox();
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

  function styleNovaBeatCategory(item:TextMenuItem, labelText:String):Void
  {
    // Retain the native TextMenuItem as the focusable hit target, but replace
    // its FNF atlas lettering with NovaBeat's clean sans-serif label.
    item.atlasText.visible = false;
    item.makeGraphic(FlxG.width, 62, 0x00000000);
    item.setPosition(0, item.y);
    item.updateHitbox();

    var label:FlxText = new FlxText(0, item.y + 8, FlxG.width, labelText, 25);
    label.setFormat("Arial Black", 25, 0xFFDCEBFF, FlxTextAlign.CENTER);
    label.cameras = [menuCamera];
    label.scrollFactor.copyFrom(item.scrollFactor);
    add(label);
    categoryLabels.push(label);
  }

  function layoutNovaBeatCategoryItems(width:Int, height:Int):Void
  {
    if (width <= 0 || height <= 0 || categoryItems.length == 0) return;

    var portrait:Bool = height > width * 1.12;
    var availableTop:Float = Math.max(76, height * 0.12);
    var availableBottom:Float = height * 0.84;
    var availableHeight:Float = Math.max(100, availableBottom - availableTop);
    var gap:Float = portrait ? Math.min(110, availableHeight / Math.max(1, categoryItems.length)) : 112;
    var rowHeight:Float = 62;
    var groupHeight:Float = rowHeight + Math.max(0, categoryItems.length - 1) * gap;
    var startY:Float = availableTop + Math.max(0, (availableHeight - groupHeight) * 0.5);

    for (index in 0...categoryItems.length)
    {
      var item:TextMenuItem = categoryItems[index];
      item.scale.set(portrait ? 0.86 : 1.0, portrait ? 0.86 : 1.0);
      item.setPosition(0, startY + index * gap);
      item.makeGraphic(width, Std.int(rowHeight), 0x00000000);
      item.updateHitbox();

      if (index < categoryLabels.length)
      {
        var label:FlxText = categoryLabels[index];
        label.setPosition(0, item.y + 8);
        label.fieldWidth = width;
        label.size = portrait ? 22 : 25;
      }
    }

    if (camFollow != null) camFollow.setPosition(width * 0.5, height * 0.5);
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (width <= 0 || height <= 0) return;
    menuCamera.setSize(width, height);
    hudCamera.setSize(width, height);
    var portrait:Bool = height > width * 1.12;
    if (novaBeatStyle)
    {
      layoutNovaBeatCategoryItems(width, height);
      menuCamera.deadzone.set(0, height * 0.14, width, height * 0.72);
    }
    else
    {
      layoutFNFCategoryItems(width, height);
    }
    if (!novaBeatStyle)
    {
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
    }
    #if FEATURE_TOUCH_CONTROLS
    if (responsiveBackButton != null)
      responsiveBackButton.setPosition(width - responsiveBackButton.width - 18, height - responsiveBackButton.height - 18);
    #end
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    #if FEATURE_TOUCH_CONTROLS
    if (novaBeatStyle && items != null)
    {
      for (index in 0...categoryItems.length)
      {
        var item:TextMenuItem = categoryItems[index];
        if (TouchUtil.pressAction(item, menuCamera, true) && !items.busy)
        {
          if (items.selectedIndex != index) items.selectItem(index);
          items.accept();
          break;
        }
      }
    }
    #end

    if (novaBeatStyle && camFollow != null && items != null && items.selectedItem != null)
      camFollow.y = items.selectedItem.y;
    else if (!novaBeatStyle)
      layoutFNFCategoryItems(FlxG.width, FlxG.height);
    if (novaBeatStyle)
    {
      for (index in 0...categoryLabels.length)
        categoryLabels[index].color = index == items.selectedIndex ? FlxColor.WHITE : 0xFFB7C9E8;
    }
  }

  override function destroy():Void
  {
    super.destroy();
    if (FlxG.cameras.list.contains(menuCamera)) FlxG.cameras.remove(menuCamera);
    if (FlxG.cameras.list.contains(hudCamera)) FlxG.cameras.remove(hudCamera);
  }
}
