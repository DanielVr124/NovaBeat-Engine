package funkin.ui;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxSignal.FlxTypedSignal;
import funkin.audio.FunkinSound;
import funkin.Preferences;
import funkin.util.TouchUtil;
import funkin.util.DeviceUtil;
import funkin.util.DeviceUtil;
import funkin.util.SwipeUtil;
import funkin.ui.Page.PageName;
import flixel.tweens.FlxEase;
import funkin.util.HapticUtil;
import flixel.tweens.FlxTween;

@:nullSafety
class MenuTypedList<T:MenuListItem> extends FlxTypedGroup<T>
{
  // Pause input variable
  public static var pauseInput:Bool = false;

  public var selectedIndex(default, null):Int = 0;
  public var selectedItem(get, never):T;

  /** Called when a new item is highlighted */
  public var onChange(default, null) = new FlxTypedSignal<T->Void>();

  /** Called when an item is accepted */
  public var onAcceptPress(default, null) = new FlxTypedSignal<T->Void>();

  /** The navigation control scheme to use */
  public var navControls:NavControls;

  /** Set to false to disable nav control */
  public var enabled:Bool = true;

  /**  */
  public var wrapMode:WrapMode = Both;

  var byName = new Map<String, T>();

  /** Set to true, internally to disable controls, without affecting vars like `enabled` */
  public var busy:Bool = false;

  // bit awkward because BACK is also a menu control and this doesn't affect that
  // #if mobile

  /** touchBuddy over here helps with the touch input! Because overlap for touch does not account for the graphic, only the hitbox.
   * And, `FlxG.pixelPerfectOverlap` uses two FlxSprites, so we can't use the `FlxTouch` object */
  public var touchBuddy:FlxSprite;

  // #end

  /** Only used in Options, basically acts the same as OptionsState's `currentName`, it's the current name of the current page in OptionsState.
   * Why is it needed? Because touch control's a bitch. Thats why. */
  public var currentPage:Null<PageName>;

  // Helper variable
  var _isMainMenuState:Bool = false;

  /** Start point and item for a mobile/Quest pointer tap. */
  var pointerTapActive:Bool = false;
  var pointerTapStartX:Float = 0;
  var pointerTapStartY:Float = 0;
  var pointerTapItem:Int = -1;

  static inline final POINTER_TAP_MAX_DISTANCE:Float = 32;

  public function new(navControls:NavControls = Vertical, ?wrapMode:WrapMode)
  {
    this.navControls = navControls;

    if (wrapMode != null) this.wrapMode = wrapMode;
    else
    {
      this.wrapMode = switch (navControls)
      {
        case Horizontal:
          Horizontal;
        case Vertical:
          Vertical;
        default:
          Both;
      }
    }

    touchBuddy = new FlxSprite().makeGraphic(10, 10);
    _isMainMenuState = Std.isOfType(FlxG.state, funkin.ui.mainmenu.MainMenuState);

    super();
  }

  public function addItem(name:String, item:T):T
  {
    if (length == selectedIndex) item.select();

    byName[name] = item;
    return add(item);
  }

  public function resetItem(oldName:String, newName:String, ?callback:Void->Void):Null<T>
  {
    var item = byName[oldName];
    if (item == null) throw 'No item named: $oldName';
    byName.remove(oldName);
    byName[newName] = item;
    item.setItem(newName, callback);

    return item;
  }

  override function update(elapsed:Float)
  {
    super.update(elapsed);

    if (enabled && !busy && !pauseInput) updateControls();
  }

  inline function updateControls():Void
  {
    var controls = PlayerSettings.player1.controls;

    var wrapX = wrapMode.match(Horizontal | Both);
    var wrapY = wrapMode.match(Vertical | Both);

    var newIndex = 0;

    // Define unified input handlers
    final inputUp:Bool = controls.UI_UP_P || (!_isMainMenuState && SwipeUtil.swipeUp);
    final inputDown:Bool = controls.UI_DOWN_P || (!_isMainMenuState && SwipeUtil.swipeDown);
    final inputLeft:Bool = controls.UI_LEFT_P || (!_isMainMenuState && SwipeUtil.swipeLeft);
    final inputRight:Bool = controls.UI_RIGHT_P || (!_isMainMenuState && SwipeUtil.swipeRight);

    // Keepin' these for keyboard/controller support on mobile platforms
    newIndex = switch (navControls)
    {
      case Vertical:
        navList(inputUp, inputDown, wrapY);
      case Horizontal:
        navList(inputLeft, inputRight, wrapX);
      case Both:
        navList(inputLeft || inputUp, inputRight || inputDown, !wrapMode.match(None));

      case Columns(num):
        navGrid(num, inputLeft, inputRight, wrapX, inputUp, inputDown, wrapY);
      case Rows(num):
        navGrid(num, inputUp, inputDown, wrapY, inputLeft, inputRight, wrapX);
    };

    #if !mobile
    // Some desktop keyboard layouts do not expose arrows through the control
    // remapping layer. Keep raw arrow keys as a fallback for the main menu.
    if (_isMainMenuState && newIndex == selectedIndex)
    {
      if (FlxG.keys.justPressed.UP && !controls.UI_UP_P)
        newIndex = navAxis(selectedIndex, members.length, true, false, wrapY);
      else if (FlxG.keys.justPressed.DOWN && !controls.UI_DOWN_P)
        newIndex = navAxis(selectedIndex, members.length, false, true, wrapY);
    }
    #end

    #if FEATURE_TOUCH_CONTROLS
    if (DeviceUtil.isMobileBrowser)
    {
      // Keep controller navigation available, but let an actual tap/click take
      // priority even when a controller is connected (common on Quest).
      final pointerEvent:Bool = TouchUtil.touch != null
        && (TouchUtil.pressed || TouchUtil.justPressed || TouchUtil.justReleased);

      if (funkin.mobile.input.ControlsHandler.usingExternalInputDevice && !pointerEvent)
      {
        if (newIndex != selectedIndex)
        {
          playNavigationSound();
          selectItem(newIndex);
        }
      }
      else
      {
        if (TouchUtil.justPressed) beginPointerTap();
        if (TouchUtil.justReleased) finishPointerTap();
      }

      // Swipes continue to navigate lists; they are not treated as clicks.
      if (newIndex != selectedIndex && !_isMainMenuState)
      {
        playNavigationSound();
        selectItem(newIndex);
      }
    }
    else if (newIndex != selectedIndex)
    {
      // Ordinary desktop web keyboard/controller selection remains unchanged.
      playNavigationSound();
      selectItem(newIndex);
    }
    #else
    if (newIndex != selectedIndex)
    {
      playNavigationSound();
      selectItem(newIndex);
    }
    #end

    // Todo: bypass popup blocker on firefox
    if (controls.ACCEPT_P) accept();

    return;
  }

  /**
   * Captures the start of a touch or Quest ray-pointer tap. A short movement
   * allowance absorbs controller-ray jitter without turning swipes into clicks.
   */
  function beginPointerTap():Void
  {
    if (TouchUtil.touch == null) return;

    pointerTapActive = true;
    pointerTapStartX = TouchUtil.touch.x;
    pointerTapStartY = TouchUtil.touch.y;
    pointerTapItem = findPointerItem();
  }

  /**
   * Activates an item only when the pointer is released over the same item
   * where the press began. This makes one tap enough to open a menu row.
   */
  function finishPointerTap():Void
  {
    if (!pointerTapActive || TouchUtil.touch == null)
    {
      clearPointerTap();
      return;
    }

    final deltaX:Float = TouchUtil.touch.x - pointerTapStartX;
    final deltaY:Float = TouchUtil.touch.y - pointerTapStartY;
    final movedDistance:Float = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
    final releasedItem:Int = findPointerItem();

    if (movedDistance <= POINTER_TAP_MAX_DISTANCE
      && pointerTapItem >= 0
      && releasedItem == pointerTapItem
      && releasedItem < members.length
      && members[releasedItem].available)
    {
      final item:T = members[releasedItem];

      if (selectedIndex != releasedItem)
      {
        playNavigationSound();
        selectItem(releasedItem);
      }

      if (_isMainMenuState)
      {
        FlxTween.cancelTweensOf(item);
        item.scale.set(1.1, 1.1);
        FlxTween.tween(item.scale, {x: 1, y: 1}, 0.3, {ease: FlxEase.backOut});
        HapticUtil.vibrate(0, 0.05, 1);
      }

      accept();
    }

    clearPointerTap();
  }

  /** Returns the item directly under the current pointer, or -1. */
  function findPointerItem():Int
  {
    if (TouchUtil.touch == null) return -1;

    touchBuddy.setPosition(TouchUtil.touch.x, TouchUtil.touch.y);

    for (i in 0...members.length)
    {
      final item:T = members[i];
      if (!item.available) continue;

      // Main-menu entries use their artwork's visible pixels. Other menus use
      // each item's own camera, never a hard-coded global camera-list index.
      final overlaps:Bool = _isMainMenuState
        ? FlxG.pixelPerfectOverlap(touchBuddy, item, 0)
        : TouchUtil.overlaps(item);

      if (overlaps) return i;
    }

    return -1;
  }

  function clearPointerTap():Void
  {
    pointerTapActive = false;
    pointerTapItem = -1;
    pointerTapStartX = 0;
    pointerTapStartY = 0;
  }

  function playNavigationSound():Void
  {
    var soundName:String = Preferences.menuStyle == "NovaBeat" ? "novabeat/select" : "scrollMenu";
    FunkinSound.playOnce(Paths.sound(soundName), 0.4);
  }

  function navAxis(index:Int, size:Int, prev:Bool, next:Bool, allowWrap:Bool):Int
  {
    if (prev == next) return index;

    if (prev)
    {
      if (index > 0) index--;
      else if (allowWrap) index = size - 1;
    }
    else
    {
      if (index < size - 1) index++;
      else if (allowWrap) index = 0;
    }

    return index;
  }

  /**
   * Controls navigation on a linear list of items such as Vertical.
   * @param prev
   * @param next
   * @param allowWrap
   */
  inline function navList(prev:Bool, next:Bool, allowWrap:Bool)
  {
    return navAxis(selectedIndex, length, prev, next, allowWrap);
  }

  /**
   * Controls navigation on a grid
   * @param latSize   The size of the fixed axis of the grid, or the "lateral axis"
   * @param latPrev   Whether the 'prev' key is pressed along the fixed-lengthed axis. eg: "left" in Column mode
   * @param latNext   Whether the 'next' key is pressed along the fixed-lengthed axis. eg: "right" in Column mode
   * @param prev      Whether the 'prev' key is pressed along the variable-lengthed axis. eg: "up" in Column mode
   * @param next      Whether the 'next' key is pressed along the variable-lengthed axis. eg: "down" in Column mode
   * @param allowWrap unused
   */
  function navGrid(latSize:Int, latPrev:Bool, latNext:Bool, latAllowWrap:Bool, prev:Bool, next:Bool, allowWrap:Bool):Int
  {
    // The grid length along the variable-length axis
    var size = Math.ceil(length / latSize);
    // The selected position along the variable-length axis
    var index = Math.floor(selectedIndex / latSize);
    // The selected position along the fixed axis
    var latIndex = selectedIndex % latSize;

    latIndex = navAxis(latIndex, latSize, latPrev, latNext, latAllowWrap);
    index = navAxis(index, size, prev, next, allowWrap);

    return Std.int(Math.min(length - 1, index * latSize + latIndex));
  }

  public function accept():Void
  {
    var menuItem:T = members[selectedIndex];

    if (!menuItem.available) return;

    onAcceptPress.dispatch(menuItem);

    if (menuItem.fireInstantly) menuItem.callback();
    else
    {
      busy = true;
      FunkinSound.playOnce(Paths.sound(Preferences.menuStyle == 'NovaBeat' ? 'novabeat/confirm' : 'confirmMenu'));
      FlxFlicker.flicker(menuItem, 1, 0.06, true, false, function(_)
      {
        busy = false;
        menuItem.callback();
      });
    }
  }

  public function cancelAccept():Void
  {
    FlxFlicker.stopFlickering(members[selectedIndex]);
    busy = false;
  }

  /**
   * Selects an item in the list. If the item is not available, it will select the next available item.
   * @param index The index of the item to select.
   */
  public function selectItem(index:Int):Void
  {
    // Protect callers from stale indices after a menu is rebuilt or a
    // conditionally available item is removed.
    if (members.length == 0) return;

    index = Std.int(Math.max(0, Math.min(index, members.length - 1)));

    // Skip unavailable entries in the requested direction without ever
    // stepping beyond the end of the array. Keep this check centralized so
    // every menu (including the Mods entry) uses the same safe selection path.
    if (!members[index].available)
    {
      final direction:Int = (index < selectedIndex) ? -1 : 1;
      var candidate:Int = index;
      var found:Bool = false;

      while (candidate >= 0 && candidate < members.length)
      {
        if (members[candidate].available)
        {
          index = candidate;
          found = true;
          break;
        }
        candidate += direction;
      }

      if (!found) return;
    }

    if (selectedIndex >= 0 && selectedIndex < members.length)
      members[selectedIndex].idle();

    selectedIndex = index;

    var selectedMenuItem:T = members[selectedIndex];
    selectedMenuItem.select();
    onChange.dispatch(selectedMenuItem);
  }

  public function has(name:String):Bool
  {
    return byName.exists(name);
  }

  public function getItem(name:String):Null<T>
  {
    return byName[name];
  }

  override function destroy():Void
  {
    super.destroy();
    byName.clear();
    onChange.removeAll();
    onAcceptPress.removeAll();
  }

  inline function get_selectedItem():T
  {
    return members[selectedIndex];
  }
}

@:nullSafety
class MenuListItem extends FlxSprite
{
  public var callback:Void->Void;
  public var name:String;
  public var available:Bool;

  /**
   * Set to true for things like opening URLs otherwise, it may it get blocked.
   */
  public var fireInstantly:Bool = false;

  public var selected(get, never):Bool;

  function get_selected() return alpha == 1.0;

  public function new(x = 0.0, y = 0.0, name:String, callback, available:Bool = true)
  {
    super(x, y);

    // This is just here to satisfy the null-safety checker
    // setData still needs to be called since other classes may override it
    this.name = name;
    this.callback = callback;
    this.available = available;
    setData(name, callback, available);
    idle();
  }

  function setData(name:String, ?callback:Void->Void, available:Bool):Void
  {
    this.name = name;

    if (callback != null) this.callback = callback;

    this.available = available;
  }

  /**
   * Calls setData and resets/redraws the state of the item
   * @param name      the label.
   * @param callback  Unchanged if null.
   */
  public function setItem(name:String, ?callback:Void->Void):Void
  {
    setData(name, callback, available);

    if (selected) select();
    else
      idle();
  }

  public function idle():Void
  {
    alpha = 0.6;
  }

  public function select():Void
  {
    alpha = 1.0;
  }
}

@:nullSafety
class MenuTypedItem<T:FlxSprite> extends MenuListItem
{
  public var label(default, set):Null<T>;

  public function new(x = 0.0, y = 0.0, label:T, name:String, callback, available:Bool = true)
  {
    super(x, y, name, callback, available);
    // set label after super otherwise setters fuck up
    this.label = label;
  }

  /**
   * Use this when you only want to show the label
   */
  public function setEmptyBackground()
  {
    var oldWidth = width;
    var oldHeight = height;
    makeGraphic(1, 1, 0x0);
    width = oldWidth;
    height = oldHeight;
  }

  function set_label(value:Null<T>):Null<T>
  {
    if (value != null)
    {
      value.x = x;
      value.y = y;
      value.alpha = alpha;
    }
    return this.label = value;
  }

  override function update(elapsed:Float)
  {
    super.update(elapsed);
    if (label != null) label.update(elapsed);
  }

  override function draw()
  {
    super.draw();
    if (label != null)
    {
      label.cameras = cameras;
      label.scrollFactor.copyFrom(scrollFactor);
      label.draw();
    }
  }

  override function set_alpha(value:Float):Float
  {
    super.set_alpha(value);

    if (label != null) label.alpha = alpha;

    return alpha;
  }

  override function set_x(value:Float):Float
  {
    super.set_x(value);

    if (label != null) label.x = x;

    return x;
  }

  override function set_y(Value:Float):Float
  {
    super.set_y(Value);

    if (label != null) label.y = y;

    return y;
  }
}

enum NavControls
{
  Horizontal;
  Vertical;
  Both;
  Columns(num:Int);
  Rows(num:Int);
}

enum WrapMode
{
  Horizontal;
  Vertical;
  Both;
  None;
}
