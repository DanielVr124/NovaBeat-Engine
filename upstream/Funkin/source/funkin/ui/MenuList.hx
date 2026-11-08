package funkin.ui;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxSignal.FlxTypedSignal;
import funkin.audio.FunkinSound;
import funkin.util.TouchUtil;
import funkin.util.DeviceUtil;
import funkin.util.SwipeUtil;
import funkin.Preferences;
import funkin.ui.Page.PageName;
import flixel.tweens.FlxEase;
import funkin.util.HapticUtil;
import flixel.tweens.FlxTween;

@:nullSafety
class MenuTypedList<T:MenuListItem> extends FlxTypedGroup<T>
{
  // Pause input variable
  public static var pauseInput:Bool = false;

  // Prevent the action that opens a page from also activating a control on it.
  public static var inputHandoffBlocked:Bool = false;
  static var inputHandoffReleaseObserved:Bool = false;

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

  /**
   * When enabled, touching a different row both selects and accepts it.
   * Keep disabled by default so existing FNF menus retain their stock behavior.
   */
  public var acceptOnTouchSelection:Bool = false;

  /**
   * Lets a page handle touch releases itself when it needs a custom camera or
   * hitbox path. Keyboard/controller navigation and touch-drag scrolling stay
   * enabled; only this list's automatic tap-selection path is skipped.
   */
  public var ignoreTouchPointerSelection:Bool = false;

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

  // Helper variables
  var _isMainMenuState:Bool = false;
  var _isPrimaryMainMenuState:Bool = false;
  var touchScrollAccumulator:Float = 0;

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
    _isPrimaryMainMenuState = _isMainMenuState
      || Std.isOfType(FlxG.state, funkin.ui.mainmenu.NovaBeatMainMenuState);

    super();
  }

  public function addItem(name:String, item:T):T
  {
    if (length == selectedIndex) item.select();

    // Keep NovaBeat's transparent hit rows on the same camera as their list.
    // All mobile menu presses and swipes use the original FNF TouchUtil path.
    if (Preferences.menuStyle == "NovaBeat" && cameras != null) item.cameras = cameras;

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

  inline function playMenuSelectionSound():Void
  {
    final soundName:String = Preferences.menuStyle == "NovaBeat" ? "novabeat/select" : "scrollMenu";
    FunkinSound.playOnce(Paths.sound(soundName), 0.4);
  }

  inline function updateControls():Void
  {
    var controls = PlayerSettings.player1.controls;

    if (inputHandoffBlocked)
    {
      touchScrollAccumulator = 0;
      if (controls.ACCEPT || TouchUtil.pressed || FlxG.mouse.pressed)
      {
        inputHandoffReleaseObserved = false;
      }
      else if (!inputHandoffReleaseObserved)
      {
        inputHandoffReleaseObserved = true;
      }
      else
      {
        inputHandoffBlocked = false;
        inputHandoffReleaseObserved = false;
      }
      return;
    }

    var touchDragUp:Bool = false;
    var touchDragDown:Bool = false;
    #if FEATURE_TOUCH_CONTROLS
    #if (mobile || web)
    if (DeviceUtil.isMobileBrowser && !_isPrimaryMainMenuState && navControls == Vertical)
    {
      if (TouchUtil.pressed && TouchUtil.touch != null)
      {
        var deltaY:Float = TouchUtil.touch.deltaViewY;
        if (Math.isFinite(deltaY))
        {
          touchScrollAccumulator -= deltaY;
          var rowHeight:Float = selectedItem == null ? 48 : selectedItem.height;
          var step:Float = Math.max(30, rowHeight * 0.55);
          if (touchScrollAccumulator >= step)
          {
            touchDragDown = true;
            touchScrollAccumulator -= step;
          }
          else if (touchScrollAccumulator <= -step)
          {
            touchDragUp = true;
            touchScrollAccumulator += step;
          }
        }
      }
      else if (TouchUtil.justReleased)
      {
        touchScrollAccumulator = 0;
      }
    }
    #end
    #end

    var wrapX = wrapMode.match(Horizontal | Both);
    var wrapY = wrapMode.match(Vertical | Both);

    var newIndex = 0;

    // Define unified input handlers
    final inputUp:Bool = controls.UI_UP_P || (!_isPrimaryMainMenuState && (DeviceUtil.isMobileBrowser ? touchDragUp : SwipeUtil.swipeUp));
    final inputDown:Bool = controls.UI_DOWN_P || (!_isPrimaryMainMenuState && (DeviceUtil.isMobileBrowser ? touchDragDown : SwipeUtil.swipeDown));
    final inputLeft:Bool = controls.UI_LEFT_P || (!_isPrimaryMainMenuState && SwipeUtil.swipeLeft);
    final inputRight:Bool = controls.UI_RIGHT_P || (!_isPrimaryMainMenuState && SwipeUtil.swipeRight);

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

    var pointerAccepted:Bool = false;

    #if FEATURE_TOUCH_CONTROLS
    #if web
    // The HTML5 target includes touch support for phones, but desktop browsers
    // must keep normal keyboard navigation and mouse-pointer behavior.
    if (!DeviceUtil.isMobileBrowser)
    {
      // Primary menus remain keyboard/controller-driven on desktop.
      if (!_isPrimaryMainMenuState && (FlxG.mouse.justMoved || FlxG.mouse.justPressed))
      {
        for (i in 0...members.length)
        {
          final item = members[i];
          final pointerCamera = (cameras != null && cameras.length > 0) ? cameras[0] : item.camera;
          if (!item.available || !FlxG.mouse.overlaps(item, pointerCamera)) continue;

          if (selectedIndex != i)
          {
            playMenuSelectionSound();
            selectItem(i);
          }

          if (FlxG.mouse.justPressed)
          {
            accept();
            pointerAccepted = true;
          }
          break;
        }
      }

      if (newIndex != selectedIndex)
      {
        playMenuSelectionSound();
        selectItem(newIndex);
      }
    }
    else
    #end
    {
      // Mobile browsers retain native touch input, but some browsers expose
      // Some mobile browsers expose taps as synthetic FlxMouse events rather
      // than FlxTouch events. Route those taps through the same selection and
      // confirmation rules as native touch for both FNF and NovaBeat menus.
      final mobileBrowserMouseTap:Bool = DeviceUtil.isMobileBrowser && FlxG.mouse.justReleased;
      if (TouchUtil.pressed)
      {
        touchBuddy.setPosition(TouchUtil.touch.x, TouchUtil.touch.y);
      }
      else if (mobileBrowserMouseTap)
      {
        touchBuddy.setPosition(FlxG.mouse.x, FlxG.mouse.y);
      }

      if (funkin.mobile.input.ControlsHandler.usingExternalInputDevice)
      {
        if (newIndex != selectedIndex)
        {
          playMenuSelectionSound();
          selectItem(newIndex);
        }
      }
      else if ((TouchUtil.pressed || mobileBrowserMouseTap) && !ignoreTouchPointerSelection)
      {
        for (i in 0...members.length)
        {
          final item = members[i];
          final menuCamera = FlxG.cameras.list[1];

          // If this list declares a camera, use that exact viewport for hit-testing.
          // This matters for added Options pages because they can own cameras other
          // than the stock global camera at index 1. Unmodified FNF lists retain the
          // original fallback, while NovaBeat rows use their assigned camera.
          final touchCamera = (cameras != null && cameras.length > 0)
            ? cameras[0]
            : (Preferences.menuStyle == "NovaBeat" ? item.camera : menuCamera);
          final itemOverlaps:Bool = !_isMainMenuState && (mobileBrowserMouseTap ? FlxG.mouse.overlaps(item, touchCamera) : TouchUtil.overlaps(item, touchCamera));
          final itemPixelOverlap:Bool = _isMainMenuState && FlxG.pixelPerfectOverlap(touchBuddy, item, 0);

          final isTouchingItem:Bool = itemOverlaps || itemPixelOverlap;

          if (item.available && isTouchingItem && (TouchUtil.justPressed || mobileBrowserMouseTap))
          {
            var prevIndex:Int = selectedIndex;

            if (!_isMainMenuState && selectedIndex != i && !acceptOnTouchSelection)
            {
              newIndex = i;
              break;
            }
            else
            {
              // Keep the tapped row as the current navigation index. Without
              // this assignment, the pre-touch keyboard index can overwrite a
              // first-tap selection at the end of this update.
              if (!_isMainMenuState) newIndex = i;
              playMenuSelectionSound();
              selectItem(i);
            }

            if (_isMainMenuState)
            {
              if (prevIndex == i || (Preferences.menuStyle == "NovaBeat" && DeviceUtil.isMobileBrowser))
              {
                FlxTween.cancelTweensOf(item);
                item.scale.set(1.1, 1.1);
                FlxTween.tween(item.scale, {x: 1, y: 1}, 0.3, {ease: FlxEase.backOut});

                HapticUtil.vibrate(0, 0.05, 1);
                accept();
              }
              else
              {
                FlxTween.cancelTweensOf(item);
                item.scale.set(0.94, 0.94);
                FlxTween.tween(item.scale, {x: 1, y: 1}, 0.3, {ease: FlxEase.backOut});

                HapticUtil.vibrate(0, 0.01, 0.5);
              }
            }
            else
            {
              accept();
            }

            break;
          }
        }
      }

      if (newIndex != selectedIndex && !_isMainMenuState)
      {
        playMenuSelectionSound();
        selectItem(newIndex);
      }
    }
    #else
    if (newIndex != selectedIndex)
    {
      playMenuSelectionSound();
      selectItem(newIndex);
    }
    #end

    // Todo: bypass popup blocker on firefox
    if (controls.ACCEPT_P && !pointerAccepted) accept();

    return;
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
    if (members.length == 0 || selectedIndex < 0 || selectedIndex >= members.length) return;
    var menuItem:T = members[selectedIndex];

    if (!menuItem.available) return;

    inputHandoffBlocked = true;
    inputHandoffReleaseObserved = false;
    onAcceptPress.dispatch(menuItem);

    // NovaBeat uses separate visible labels over transparent hit rows; skip
    // the stock flicker delay for those invisible targets.
    if (menuItem.fireInstantly || Preferences.menuStyle == "NovaBeat") menuItem.callback();
    else
    {
      busy = true;
      FunkinSound.playOnce(Paths.sound('confirmMenu'));
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
    if (members.length == 0) return;
    index = Std.int(Math.max(0, Math.min(index, members.length - 1)));
    members[selectedIndex].idle();

    if (!members[index].available)
    {
      if (index < selectedIndex)
      {
        final newIndex:Int = (index - 1 < 0) ? index + 1 : index - 1;
        selectItem(newIndex);
        return;
      }
      else if (index > selectedIndex)
      {
        final newIndex:Int = (index + 1 > members.length) ? index - 1 : index + 1;
        selectItem(newIndex);
        return;
      }
    }

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
