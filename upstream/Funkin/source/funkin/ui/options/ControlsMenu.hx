package funkin.ui.options;

import funkin.util.InputUtil;
import funkin.Preferences;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.FlxObject;
import funkin.graphics.FunkinCamera;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;
import funkin.graphics.FunkinSprite;
import funkin.input.Controls.Device;
import funkin.input.Controls.Control;
import funkin.ui.AtlasText;
import funkin.ui.MenuList.MenuTypedList;
import funkin.ui.TextMenuList;
import funkin.ui.Page;
#if FEATURE_TOUCH_CONTROLS
import funkin.mobile.ui.FunkinBackButton;
#end
import funkin.util.DeviceUtil;

class ControlsMenu extends Page<OptionsState.OptionsMenuPageName>
{
  public static inline final COLUMNS = 2;
  static var controlList = Control.createAll();

  /**
   * Defines groups of controls that cannot share inputs, like left and right. Say, if ACCEPT is Z, Back is X,
   * if the player sets Back to Z it also set ACCEPT to X. This prevents the player from setting the controls in
   * a way the prevents them from changing more controls or exiting the menu.
   */
  static var controlGroups:Array<Array<Control>> = [
    [NOTE_UP, NOTE_DOWN, NOTE_LEFT, NOTE_RIGHT],
    [
      UI_UP,
      UI_DOWN,
      UI_LEFT,
      UI_RIGHT,
      ACCEPT,
      BACK
    ],
    [CUTSCENE_ADVANCE],
    [FREEPLAY_FAVORITE, FREEPLAY_LEFT, FREEPLAY_RIGHT, FREEPLAY_CHAR_SELECT],
    [
      WINDOW_FULLSCREEN,
      #if FEATURE_SCREENSHOTS WINDOW_SCREENSHOT, #end
    ],
    [VOLUME_UP, VOLUME_DOWN, VOLUME_MUTE],
    [
      #if FEATURE_DEBUG_MENU DEBUG_MENU, #end
      #if FEATURE_CHART_EDITOR DEBUG_CHART, #end
      #if FEATURE_STAGE_EDITOR DEBUG_STAGE, #end
      DEBUG_DISPLAY
    ]
  ];

  var itemGroups:Array<Array<InputItem>> = [
    for (i in 0...controlGroups.length) []
  ];
  var controlGrid:MenuTypedList<InputItem>;
  var deviceList:TextMenuList;
  var menuCamera:FlxCamera;
  var prompt:Prompt;
  var popup:Prompt;
  var camFollow:FlxObject;
  var labels:FlxTypedGroup<AtlasText>;
  var currentDevice:Device = Keys;
  var deviceListSelected:Bool = false;
  var actionPrevented:Bool = false;
  var novaBeatStyle:Bool = false;
  var novaBeatRows:FlxTypedGroup<FunkinSprite>;
  var headersLayer:FlxTypedGroup<AtlasText>;
  var novaBeatTextLayer:FlxTypedGroup<FlxText>;
  var novaBeatRowText:Array<FlxText> = [];
  var novaBeatHeaderText:Array<FlxText> = [];
  var novaBeatDeviceText:Array<FlxText> = [];
  var novaBeatBindingText:Array<FlxText> = [];
  var novaBeatRowBackgrounds:Array<FunkinSprite> = [];
  var bindingPlates:Array<FunkinSprite> = [];
  var controlRowBaseY:Array<Float> = [];
  var controlHeaderBaseY:Array<Float> = [];
  var deviceBackground:Null<FunkinSprite> = null;
  #if FEATURE_TOUCH_CONTROLS
  var responsiveBackButton:Null<FunkinBackButton> = null;
  #end

  static final CONTROL_BASE_X = 50;
  static final CONTROL_MARGIN_X = 700;
  static final CONTROL_SPACING_X = 300;

  public function new()
  {
    super();
    // Entering Controls from another menu must not reuse the press that
    // opened this page as a request to bind the currently selected key.
    MenuTypedList.inputHandoffBlocked = true;

    novaBeatStyle = Preferences.menuStyle == "NovaBeat";
    menuCamera = new FunkinCamera('controlsMenu');
    FlxG.cameras.add(menuCamera, false);
    menuCamera.bgColor = 0x0;
    camera = menuCamera;
    NovaBeatOptionsChrome.apply(this, 'CONTROLS', menuCamera);

    novaBeatRows = new FlxTypedGroup<FunkinSprite>();
    novaBeatRows.cameras = [menuCamera];
    add(novaBeatRows);
    labels = new FlxTypedGroup<AtlasText>();
    labels.cameras = [menuCamera];
    headersLayer = new FlxTypedGroup<AtlasText>();
    headersLayer.cameras = [menuCamera];
    var headers:FlxTypedGroup<AtlasText> = headersLayer;
    controlGrid = new MenuTypedList(Columns(COLUMNS), Vertical);
    controlGrid.cameras = [menuCamera];
    novaBeatTextLayer = new FlxTypedGroup<FlxText>();
    novaBeatTextLayer.cameras = [menuCamera];

    add(labels);
    add(headers);
    add(controlGrid);

    if (FlxG.gamepads.numActiveGamepads > 0)
    {
      var devicesBg:FunkinSprite = new FunkinSprite();
      if (novaBeatStyle)
      {
        var margin:Float = Math.max(20, FlxG.width * 0.035) + 18;
        devicesBg.setPosition(margin, 84);
        devicesBg.makeSolidColor(Std.int(FlxG.width - margin * 2), 54, 0xFF0D1935);
      }
      else
      {
        devicesBg.makeSolidColor(FlxG.width, 100, 0xFFFAFD6D);
      }
      devicesBg.cameras = [menuCamera];
      deviceBackground = devicesBg;
      if (novaBeatStyle) novaBeatRows.add(devicesBg);
      else add(devicesBg);
      deviceList = new TextMenuList(Horizontal, None);
      deviceList.cameras = [menuCamera];
      add(deviceList);
      deviceListSelected = true;

      var item:TextMenuItem;

      item = deviceList.createItem('Keyboard', AtlasFont.BOLD, selectDevice.bind(Keys));
      item.x = novaBeatStyle ? FlxG.width * 0.38 : FlxG.width / 2 - item.width - 30;
      item.y = novaBeatStyle ? 99 : (devicesBg.height - item.height) / 2;
      if (novaBeatStyle)
      {
        item.atlasText.visible = false;
        var deviceLabel:FlxText = new FlxText(0, item.y + 2, 160, 'KEYBOARD', 14);
        deviceLabel.setFormat("Arial Black", 14, 0xFF63E8FF, FlxTextAlign.CENTER);
        deviceLabel.cameras = [menuCamera];
        novaBeatTextLayer.add(deviceLabel);
        novaBeatDeviceText.push(deviceLabel);
      }

      item = deviceList.createItem('Gamepad', AtlasFont.BOLD, selectDevice.bind(Gamepad(FlxG.gamepads.firstActive.id)));
      item.x = novaBeatStyle ? FlxG.width * 0.58 : FlxG.width / 2 + 30;
      item.y = novaBeatStyle ? 99 : (devicesBg.height - item.height) / 2;
      if (novaBeatStyle)
      {
        item.atlasText.visible = false;
        var deviceLabel:FlxText = new FlxText(0, item.y + 2, 160, 'GAMEPAD', 14);
        deviceLabel.setFormat("Arial Black", 14, 0xFF63E8FF, FlxTextAlign.CENTER);
        deviceLabel.cameras = [menuCamera];
        novaBeatTextLayer.add(deviceLabel);
        novaBeatDeviceText.push(deviceLabel);
      }
    }

    // FlxG.debugger.drawDebug = true;
    var y:Float = deviceList == null ? (novaBeatStyle ? 102 : 30) : (novaBeatStyle ? 166 : 120);
    var spacer:Float = novaBeatStyle ? 68 : 70;
    var currentHeader:String = null;
    // list order is determined by enum order
    for (i in 0...controlList.length)
    {
      var control = controlList[i];
      var name = control.getName();
      // Don't spoil that you can play different characters until the player has unlocked one
      if (control == FREEPLAY_CHAR_SELECT && funkin.data.freeplay.player.PlayerRegistry.instance.countUnlockedCharacters() <= 1)
      {
        continue;
      }

      if (currentHeader != "UI_" && name.indexOf("UI_") == 0)
      {
        currentHeader = "UI_";
        addControlHeader(headers, "UI", y);
        y += spacer;
      }
      else if (currentHeader != "NOTE_" && name.indexOf("NOTE_") == 0)
      {
        currentHeader = "NOTE_";
        addControlHeader(headers, "NOTES", y);
        y += spacer;
      }
      else if (currentHeader != "CUTSCENE_" && name.indexOf("CUTSCENE_") == 0)
      {
        currentHeader = "CUTSCENE_";
        addControlHeader(headers, "CUTSCENE", y);
        y += spacer;
      }
      else if (currentHeader != "FREEPLAY_" && name.indexOf("FREEPLAY_") == 0)
      {
        currentHeader = "FREEPLAY_";
        addControlHeader(headers, "FREEPLAY", y);
        y += spacer;
      }
      else if (currentHeader != "WINDOW_" && name.indexOf("WINDOW_") == 0)
      {
        currentHeader = "WINDOW_";
        addControlHeader(headers, "WINDOW", y);
        y += spacer;
      }
      else if (currentHeader != "VOLUME_" && name.indexOf("VOLUME_") == 0)
      {
        currentHeader = "VOLUME_";
        addControlHeader(headers, "VOLUME", y);
        y += spacer;
      }
      else if (currentHeader != "DEBUG_" && name.indexOf("DEBUG_") == 0)
      {
        currentHeader = "DEBUG_";
        addControlHeader(headers, "DEBUG", y);
        y += spacer;
      }

      if (currentHeader != null && name.indexOf(currentHeader) == 0) name = name.substr(currentHeader.length);

      var formatName = name.replace('_', ' ');
      var labelX:Float = novaBeatStyle ? Math.max(20, FlxG.width * 0.035) + 30 : Math.max(FullScreenScaleMode.gameNotchSize.x, CONTROL_BASE_X);
      if (novaBeatStyle)
      {
        var rowX:Float = Math.max(20, FlxG.width * 0.035) + 18;
        var rowW:Float = FlxG.width - rowX * 2;
        var rowBackground:FunkinSprite = new FunkinSprite(rowX, y - 7);
        rowBackground.makeSolidColor(Std.int(rowW), 54, 0xFF0D1935);
        rowBackground.cameras = [menuCamera];
        novaBeatRows.add(rowBackground);
        novaBeatRowBackgrounds.push(rowBackground);

        var firstBindX:Float = FlxG.width * 0.57;
        var secondBindX:Float = FlxG.width * 0.78;
        addBindingPlate(firstBindX, y - 2);
        addBindingPlate(secondBindX, y - 2);
      }

      var label = labels.add(new AtlasText(labelX, y, formatName, AtlasFont.BOLD));
      controlRowBaseY.push(y);
      label.cameras = [menuCamera];
      label.alpha = novaBeatStyle ? 1.0 : 0.6;
      if (novaBeatStyle)
      {
        label.visible = false;
        var modernLabel:FlxText = new FlxText(labelX, y + 5, FlxG.width * 0.43, formatName, 15);
        modernLabel.setFormat("Arial Black", 15, 0xFFDCEBFF, FlxTextAlign.LEFT);
        modernLabel.cameras = [menuCamera];
        novaBeatTextLayer.add(modernLabel);
        novaBeatRowText.push(modernLabel);
      }

      for (i in 0...COLUMNS)
      {
        var bindX:Float = novaBeatStyle
          ? (i == 0 ? FlxG.width * 0.57 + 12 : FlxG.width * 0.78 + 12)
          : label.x + CONTROL_MARGIN_X + i * CONTROL_SPACING_X;
        var binding:InputItem = createItem(bindX, y, control, i);
        if (novaBeatStyle)
        {
          binding.atlasText.visible = false;
          var bindingLabel:FlxText = new FlxText(bindX, y + 5, 132, binding.getLabel(binding.input), 14);
          bindingLabel.setFormat("Arial", 14, 0xFF63E8FF, FlxTextAlign.CENTER);
          bindingLabel.cameras = [menuCamera];
          novaBeatTextLayer.add(bindingLabel);
          novaBeatBindingText.push(bindingLabel);
        }
      }

      y += spacer;
    }

    camFollow = new FlxObject(FlxG.width / 2, 0, 70, 70);
    if (deviceList != null)
    {
      camFollow.y = deviceList.selectedItem.y;
      controlGrid.selectedItem.idle();
      controlGrid.enabled = false;
    }
    else
      camFollow.y = controlGrid.selectedItem.y;

    menuCamera.follow(camFollow, null, 0.06);
    var margin = 100;
    menuCamera.deadzone.set(0, margin, menuCamera.width, menuCamera.height - margin * 2);
    menuCamera.minScrollY = 0;
    controlGrid.onChange.add(function(selected)
    {
      camFollow.y = selected.y;

      labels.forEach((label) -> label.alpha = novaBeatStyle ? 0.0 : 0.6);
      var labelIndex:Int = Std.int(controlGrid.selectedIndex / COLUMNS);
      if (labelIndex >= 0 && labelIndex < labels.members.length)
      {
        labels.members[labelIndex].alpha = novaBeatStyle ? 0.0 : 1.0;
      }

      if (novaBeatStyle) updateNovaBeatControlSelection();
    });
    if (novaBeatStyle)
    {
      // Keep every upstream bitmap label hidden in the NovaBeat layout,
      // including when the keyboard/gamepad chooser is present.
      for (label in labels.members)
      {
        if (label == null) continue;
        label.visible = false;
        label.alpha = 0;
      }
      for (header in headersLayer.members)
      {
        if (header == null) continue;
        header.visible = false;
      }
      updateNovaBeatControlSelection();
      add(novaBeatTextLayer);
    }

    prompt = new Prompt("\nPress any key to rebind\n\n\nBackspace to unbind\n    Escape to cancel", None);
    prompt.create();
    prompt.createBgFromMargin(100, Preferences.menuStyle == "NovaBeat" ? 0xFF0D1935 : 0xFFfafd6d);
    prompt.back.scrollFactor.set(0, 0);
    prompt.exists = false;
    add(prompt);

    popup = new Prompt("\nYou cannot unbind\nthat key!\n\n\nEscape to exit", None);
    popup.create();
    popup.createBgFromMargin(100, Preferences.menuStyle == "NovaBeat" ? 0xFF0D1935 : 0xFFfafd6d);
    popup.back.scrollFactor.set(0, 0);
    popup.exists = false;
    add(popup);

    #if FEATURE_TOUCH_CONTROLS
    if (DeviceUtil.isMobileBrowser)
    {
      responsiveBackButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, function():Void
      {
        if (controlGrid.enabled && deviceList != null && deviceListSelected == false)
        {
          goToDeviceList();
        }
        else if (canExit)
        {
          exit();
        }
      }, 1.0);
      add(responsiveBackButton);
    }
    #end
  }

  function addControlHeader(headers:FlxTypedGroup<AtlasText>, title:String, y:Float):Void
  {
    var header:AtlasText = new AtlasText(0, y, title, AtlasFont.BOLD);
    header.cameras = [menuCamera];
    if (novaBeatStyle)
    {
      header.x = Math.max(20, FlxG.width * 0.035) + 30;
      header.color = 0xFF48E7FF;
      header.visible = false;
      var modernHeader:FlxText = new FlxText(header.x, y + 3, 260, title, 14);
      modernHeader.setFormat("Arial Black", 14, 0xFF48E7FF, FlxTextAlign.LEFT);
      modernHeader.cameras = [menuCamera];
      novaBeatTextLayer.add(modernHeader);
      novaBeatHeaderText.push(modernHeader);
    }
    else
    {
      header.screenCenter(X);
    }
    headers.add(header);
    controlHeaderBaseY.push(y);
  }

  function addBindingPlate(x:Float, y:Float):Void
  {
    var plate:FunkinSprite = new FunkinSprite(x - 8, y);
    plate.makeSolidColor(150, 42, 0xFF142747);
    plate.cameras = [menuCamera];
    novaBeatRows.add(plate);
    bindingPlates.push(plate);
  }

  function updateNovaBeatControlSelection():Void
  {
    if (!novaBeatStyle) return;
    var selectedRow:Int = Std.int(controlGrid.selectedIndex / COLUMNS);
    for (index in 0...novaBeatRowBackgrounds.length)
    {
      var selected:Bool = index == selectedRow;
      novaBeatRowBackgrounds[index].color = selected ? 0xFF123B5C : 0xFF0D1935;
      novaBeatRowBackgrounds[index].alpha = selected ? 1.0 : 0.82;
    }
    for (index in 0...novaBeatRowText.length)
      novaBeatRowText[index].color = index == selectedRow ? 0xFFFFFFFF : 0xFFDCEBFF;

    for (index in 0...controlGrid.members.length)
    {
      if (index < novaBeatBindingText.length)
      {
        var label:FlxText = novaBeatBindingText[index];
        label.color = index == controlGrid.selectedIndex ? 0xFFFFFFFF : 0xFF63E8FF;
        var binding:InputItem = controlGrid.members[index];
        label.text = binding.getLabel(binding.input);
      }
    }
  }

  function createItem(x = 0.0, y = 0.0, control:Control, index:Int)
  {
    var item = new InputItem(x, y, currentDevice, control, index, onSelect);
    for (i in 0...controlGroups.length)
    {
      if (controlGroups[i].contains(control)) itemGroups[i].push(item);
    }

    if (novaBeatStyle)
    {
      item.atlasText.visible = false;
      item.cameras = [menuCamera];
    }

    return controlGrid.addItem(item.name, item);
  }

  function onSelect():Void
  {
    switch (currentDevice)
    {
      case Keys:
        {
          if (!FlxG.keys.enabled) return;
          keyUsedToEnterPrompt = FlxG.keys.firstJustPressed();
        }
      case Gamepad(id):
        {
          if (FlxG.gamepads.getByID(id) == null) return;
          buttonUsedToEnterPrompt = FlxG.gamepads.getByID(id).firstJustPressedID();
        }
    }

    controlGrid.enabled = false;
    canExit = false;
    prompt.exists = true;
  }

  function createPopup():Void
  {
    canExit = false;
    popup.exists = true;
  }

  function goToDeviceList():Void
  {
    controlGrid.selectedItem.idle();
    labels.members[
      Std.int(controlGrid.selectedIndex / COLUMNS)
    ].alpha = 0.6;
    controlGrid.enabled = false;
    deviceList.enabled = true;
    canExit = true;
    camFollow.y = deviceList.selectedItem.y;
    deviceListSelected = true;
  }

  function selectDevice(device:Device):Void
  {
    currentDevice = device;

    for (item in controlGrid.members) item.updateDevice(currentDevice);

    var cancel = device == Keys ? "Escape" : "Back";
    // todo: alignment
    if (device == Keys)
    {
      prompt.setText('\nPress any key to rebind\n\n\n\n    $cancel to cancel');
      popup.setText('\nYou cannot unbind\nthat key!\n\n\n$cancel to exit');
    }
    else
    {
      prompt.setText('\nPress any button\n   to rebind\n\n\n $cancel to cancel');
      popup.setText('\nYou cannot unbind\nthat button!\n\n\n$cancel to exit');
    }

    controlGrid.selectedItem.select();
    labels.members[
      Std.int(controlGrid.selectedIndex / COLUMNS)
    ].alpha = 1.0;
    controlGrid.enabled = true;
    deviceList.enabled = false;
    deviceListSelected = false;
    canExit = false;
  }

  var keyUsedToEnterPrompt:Null<Int> = null;
  var buttonUsedToEnterPrompt:Null<Int> = null;

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    var controls = PlayerSettings.player1.controls;
    if (novaBeatStyle)
    {
      for (index in 0...controlGrid.members.length)
      {
        if (index < novaBeatBindingText.length)
        {
          var binding:InputItem = controlGrid.members[index];
          novaBeatBindingText[index].text = binding.getLabel(binding.input);
        }
      }
    }
    if (controlGrid.enabled && deviceList != null && deviceListSelected == false && controls.BACK) goToDeviceList();

    if (prompt.exists)
    {
      switch (currentDevice)
      {
        case Keys:
          {
            // Um?
            // Checking pressed causes problems when you change the BACK key,
            // but checking released causes problems when the prompt is instant.

            // keyUsedToEnterPrompt is my weird workaround.

            var key = FlxG.keys?.firstJustReleased();
            if (key == null) return;
            if (key != NONE && key != keyUsedToEnterPrompt)
            {
              if (key == ESCAPE)
              {
                closePrompt();
              }
              else if (key == BACKSPACE)
              {
                onInputSelect(NONE);
                closePrompt();
              }
              else
              {
                onInputSelect(key);
                closePrompt();
              }
            }
          }
        case Gamepad(id):
          {
            var button = FlxG.gamepads?.getByID(id)?.firstJustReleasedID();
            if (button == null) return;
            if (button != NONE && button != buttonUsedToEnterPrompt)
            {
              if (button != BACK) onInputSelect(button);
              closePrompt();
            }

            var key = FlxG.keys.firstJustReleased();
            if (key != NONE && key != keyUsedToEnterPrompt)
            {
              if (key == ESCAPE)
              {
                closePrompt();
              }
              else if (key == BACKSPACE)
              {
                onInputSelect(NONE);
                closePrompt();
              }
            }
          }
      }
    }

    if (actionPrevented && !popup.exists) createPopup();

    if (popup.exists)
    {
      switch (currentDevice)
      {
        case Keys:
          {
            var key = FlxG.keys?.firstJustReleased();
            if (key == ESCAPE) closePopup();
          }
        case Gamepad(id):
          {
            var button = FlxG.gamepads?.getByID(id)?.firstJustReleasedID();
            if (button == BACK) closePopup();

            var key = FlxG.keys.firstJustReleased();
            if (key == ESCAPE) closePopup();
          }
      }
    }

    switch (currentDevice)
    {
      case Keys:
        {
          var keyJustReleased:Null<Int> = FlxG.keys?.firstJustReleased();
          if (keyJustReleased == null) return;
          if (keyJustReleased != NONE && keyJustReleased == keyUsedToEnterPrompt)
          {
            keyUsedToEnterPrompt = null;
          }
          buttonUsedToEnterPrompt = null;
        }
      case Gamepad(id):
        {
          var buttonJustReleased:Null<Int> = FlxG.gamepads?.getByID(id)?.firstJustReleasedID();
          if (buttonJustReleased == null) return;
          if (buttonJustReleased != NONE && buttonJustReleased == buttonUsedToEnterPrompt)
          {
            buttonUsedToEnterPrompt = null;
          }
          keyUsedToEnterPrompt = null;
        }
    }
  }

  function onInputSelect(input:Int):Void
  {
    var item = controlGrid.selectedItem;
    var leftItem = controlGrid.members[controlGrid.selectedIndex - 1];
    var rightItem = controlGrid.members[controlGrid.selectedIndex + 1];

    // check if all keybinds are being removed and this is a UI control, prevent removing last keybind for this
    if (input == FlxKey.NONE && controlGrid.selectedIndex != 1 && rightItem.input == FlxKey.NONE)
    {
      for (group in itemGroups)
      {
        if (group.toString() == itemGroups[1].toString() && group.contains(item)) actionPrevented = true;
      }
    }

    if (actionPrevented) return;

    // check if that key is already set for this
    if (input != FlxKey.NONE)
    {
      var column0 = Math.floor(controlGrid.selectedIndex / 2) * 2;
      for (i in 0...COLUMNS)
      {
        if (controlGrid.members[column0 + i].input == input) return;
      }
    }

    // Check if items in the same group already have the new input
    for (group in itemGroups)
    {
      if (input != FlxKey.NONE && group.contains(item))
      {
        for (otherItem in group)
        {
          if (otherItem != item && otherItem.input == input)
          {
            // replace that input with this items old input.
            PlayerSettings.player1.controls.replaceBinding(otherItem.control, currentDevice, item.input, otherItem.input);
            // Don't use resetItem() since items share names/labels
            otherItem.input = item.input;
            otherItem.label.text = item.label.text;
          }
        }
      }
    }

    PlayerSettings.player1.controls.replaceBinding(item.control, currentDevice, input, item.input);

    // Don't use resetItem() since items share names/labels
    item.input = input;
    item.label.text = item.getLabel(input);

    // Shift left on the grid if the item on the right is bound and the item on the left is unbound.
    if (controlGrid.selectedIndex % 2 == 1)
    {
      if (leftItem != null && input != FlxKey.NONE && leftItem.input == FlxKey.NONE)
      {
        trace('Left item is unbound and right item is not!');
        // Swap them.
        var temp = leftItem.input;
        leftItem.input = item.input;
        item.input = temp;

        leftItem.label.text = leftItem.getLabel(leftItem.input);
        item.label.text = item.getLabel(item.input);
      }
    }
    else
    {
      if (rightItem != null && input == FlxKey.NONE && rightItem.input != FlxKey.NONE)
      {
        trace('Left item is unbound and right item is not!');
        // Swap them.
        var temp = item.input;
        item.input = rightItem.input;
        rightItem.input = temp;

        item.label.text = item.getLabel(item.input);
        rightItem.label.text = rightItem.getLabel(rightItem.input);
      }
    }

    PlayerSettings.player1.saveControls();
  }

  function closePrompt()
  {
    prompt.exists = false;
    controlGrid.enabled = true;
    if (deviceList == null) canExit = true;
  }

  function closePopup()
  {
    popup.exists = false;
    actionPrevented = false;
    if (deviceList == null) canExit = true;
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (width <= 0 || height <= 0) return;
    menuCamera.setSize(width, height);
    var portrait:Bool = height > width * 1.12;
    var margin:Float = Math.max(16, width * 0.04);
    var rowTop:Float = portrait ? (deviceList == null ? 112 : 174) : (deviceList == null ? 102 : 166);
    var rowGap:Float = portrait ? Math.min(58, Math.max(42, height * 0.072)) : (novaBeatStyle ? 68 : 70);
    var firstBaseY:Float = controlRowBaseY.length > 0 ? controlRowBaseY[0] : rowTop;
    var yScale:Float = rowGap / (novaBeatStyle ? 68 : 70);

    if (deviceBackground != null)
    {
      if (novaBeatStyle)
      {
        deviceBackground.setPosition(margin + 18, 84);
        deviceBackground.makeSolidColor(Std.int(width - (margin + 18) * 2), 54, 0xFF0D1935);
      }
      else
      {
        deviceBackground.setPosition(0, 0);
        deviceBackground.makeSolidColor(width, 100, 0xFFFAFD6D);
      }
    }
    if (deviceList != null)
    {
      for (index in 0...deviceList.members.length)
      {
        var deviceItem:TextMenuItem = deviceList.members[index];
        deviceItem.y = novaBeatStyle ? 99 : 35;
        deviceItem.x = index == 0 ? width * (portrait ? 0.27 : 0.38) - deviceItem.width * 0.5
          : width * (portrait ? 0.73 : 0.62) - deviceItem.width * 0.5;
        if (novaBeatStyle && index < novaBeatDeviceText.length)
        {
          var deviceLabel:FlxText = novaBeatDeviceText[index];
          deviceLabel.setPosition(deviceItem.x + deviceItem.width * 0.5 - 80, deviceItem.y + 2);
          deviceLabel.fieldWidth = 160;
          deviceLabel.size = portrait ? 12 : 14;
        }
      }
    }

    for (index in 0...labels.members.length)
    {
      var baseY:Float = index < controlRowBaseY.length ? controlRowBaseY[index] : firstBaseY;
      var y:Float = rowTop + (baseY - firstBaseY) * yScale;
      var label:AtlasText = labels.members[index];
      label.x = margin + (novaBeatStyle ? 18 : 8);
      label.y = y;
      label.scale.set(portrait ? 0.82 : 1.0, portrait ? 0.82 : 1.0);
      if (novaBeatStyle && index < novaBeatRowText.length)
      {
        var modernLabel:FlxText = novaBeatRowText[index];
        modernLabel.setPosition(margin + 18, y + 5);
        modernLabel.fieldWidth = width * 0.43;
        modernLabel.size = portrait ? 12 : 15;
      }
      if (novaBeatStyle && index < novaBeatRowBackgrounds.length)
      {
        var rowW:Float = width - margin * 2 - 24;
        novaBeatRowBackgrounds[index].setPosition(margin + 12, y - 7);
        novaBeatRowBackgrounds[index].makeSolidColor(Std.int(rowW), 48, 0xFF0D1935);
      }

      for (column in 0...COLUMNS)
      {
        var itemIndex:Int = index * COLUMNS + column;
        if (itemIndex >= controlGrid.members.length) continue;
        var bind:InputItem = controlGrid.members[itemIndex];
        bind.scale.set(portrait ? 0.72 : 1.0, portrait ? 0.72 : 1.0);
        bind.updateHitbox();
        var x:Float;
        if (portrait)
          x = width * (column == 0 ? 0.55 : 0.80) - bind.width * 0.5;
        else if (novaBeatStyle)
          x = width * (column == 0 ? 0.57 : 0.78) + 12;
        else
          x = label.x + CONTROL_MARGIN_X + column * CONTROL_SPACING_X;
        bind.setPosition(x, y);
      }

      if (novaBeatStyle)
      {
        var firstPlate:Int = index * COLUMNS;
        for (column in 0...COLUMNS)
        {
          var plateIndex:Int = firstPlate + column;
          if (plateIndex < bindingPlates.length)
          {
            var plate:FunkinSprite = bindingPlates[plateIndex];
            var plateX:Float = width * (portrait ? (column == 0 ? 0.55 : 0.80) : (column == 0 ? 0.57 : 0.78));
            plate.setPosition(plateX - (portrait ? 36 : 8), y - 2);
            plate.makeSolidColor(portrait ? 74 : 150, portrait ? 38 : 42, 0xFF142747);
            var bindingIndex:Int = firstPlate + column;
            if (bindingIndex < novaBeatBindingText.length)
            {
              var bindingLabel:FlxText = novaBeatBindingText[bindingIndex];
              bindingLabel.setPosition(plate.x + 4, plate.y + (plate.height - bindingLabel.height) * 0.5);
              bindingLabel.fieldWidth = plate.width - 8;
              bindingLabel.size = portrait ? 10 : 14;
            }
          }
        }
      }
    }

    for (index in 0...headersLayer.members.length)
    {
      var header:AtlasText = headersLayer.members[index];
      if (header == null) continue;
      var baseY:Float = index < controlHeaderBaseY.length ? controlHeaderBaseY[index] : firstBaseY;
      header.x = margin + 18;
      header.y = rowTop + (baseY - firstBaseY) * yScale;
      header.scale.set(portrait ? 0.85 : 1.0, portrait ? 0.85 : 1.0);
      if (novaBeatStyle && index < novaBeatHeaderText.length)
      {
        var modernHeader:FlxText = novaBeatHeaderText[index];
        modernHeader.setPosition(header.x, header.y + 3);
        modernHeader.size = portrait ? 12 : 14;
      }
    }

    if (camFollow != null)
    {
      var selectedY:Float = rowTop;
      if (deviceListSelected && deviceList != null && deviceList.selectedItem != null)
        selectedY = deviceList.selectedItem.y;
      else if (controlGrid.selectedItem != null)
        selectedY = controlGrid.selectedItem.y;
      camFollow.setPosition(width * 0.5, selectedY);
    }
    menuCamera.deadzone.set(0, height * (portrait ? 0.16 : 0.14), width, height * (portrait ? 0.68 : 0.72));
    #if FEATURE_TOUCH_CONTROLS
    if (responsiveBackButton != null)
      responsiveBackButton.setPosition(width - responsiveBackButton.width - 18, height - responsiveBackButton.height - 18);
    #end
  }

  override function destroy()
  {
    super.destroy();

    itemGroups = null;

    if (FlxG.cameras.list.contains(menuCamera)) FlxG.cameras.remove(menuCamera);
  }

  override function set_enabled(value:Bool)
  {
    if (value == false)
    {
      controlGrid.enabled = false;
      if (deviceList != null) deviceList.enabled = false;
    }
    else
    {
      controlGrid.enabled = !deviceListSelected;
      if (deviceList != null) deviceList.enabled = deviceListSelected;
    }
    return super.set_enabled(value);
  }
}

class InputItem extends TextMenuItem
{
  public var device(default, null):Device = Keys;
  public var control:Control;
  public var input:Int = -1;
  public var index:Int = -1;

  public function new(x = 0.0, y = 0.0, device, control, index, ?callback)
  {
    this.device = device;
    this.control = control;
    this.index = index;
    this.input = getInput();

    super(x, y, getLabel(input), DEFAULT, callback);

    this.fireInstantly = true;
  }

  public function updateDevice(device:Device)
  {
    if (this.device != device)
    {
      this.device = device;
      input = getInput();
      label.text = getLabel(input);
    }
  }

  function getInput()
  {
    var list = PlayerSettings.player1.controls.getInputsFor(control, device);
    list = list.distinct();
    if (list.length > index)
    {
      if (list[index] != FlxKey.ESCAPE || list[index] != FlxGamepadInputID.BACK) return list[index];

      if (list.length > ControlsMenu.COLUMNS) // Escape isn't mappable, show a third option, instead.
        return list[ControlsMenu.COLUMNS];
    }

    return -1;
  }

  public function getLabel(input:Int)
  {
    return input == FlxKey.NONE ? "---" : InputUtil.format(input, device);
  }
}
