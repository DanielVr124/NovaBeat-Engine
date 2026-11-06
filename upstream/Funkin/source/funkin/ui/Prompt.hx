package funkin.ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import funkin.ui.AtlasText.AtlasFont;

/**
 * Opens a yes/no dialog box as a substate over the current state.
 */
@:nullSafety
class Prompt extends flixel.FlxSubState
{
  inline static var MARGIN = 100;

  public var onYes:Null<Void->Void>;
  public var onNo:Null<Void->Void>;
  public var buttons:TextMenuList;
  public var field:AtlasText;
  public var back:Null<FlxSprite>;

  var style:ButtonStyle;
  var bgMargin:Null<Float> = null;
  var bgColor:FlxColor = 0xFF808080;

  public function new(text:String, style:ButtonStyle = Ok)
  {
    this.style = style;
    super(0x80000000);

    buttons = new TextMenuList(Horizontal);

    field = new AtlasText(text, AtlasFont.BOLD);
    field.scrollFactor.set(0, 0);
  }

  override function create()
  {
    super.create();

    field.y = MARGIN;
    field.screenCenter(X);
    add(field);

    createButtons();
    add(buttons);
    reflow(FlxG.width, FlxG.height);
    FlxG.signals.gameResized.add(onGameResized);
  }

  public function createBg(width:Int, height:Int, color = 0xFF808080)
  {
    bgMargin = null;
    bgColor = color;
    back = new FlxSprite();
    back.makeGraphic(width, height, color, false, "prompt-bg");
    back.screenCenter(XY);
    add(back);
    var backObj = members.pop();
    if (backObj != null) members.unshift(backObj); // bring to front
  }

  public function createBgFromMargin(margin = MARGIN, color = 0xFF808080)
  {
    bgMargin = margin;
    bgColor = color;
    createBg(Std.int(FlxG.width - margin * 2), Std.int(FlxG.height - margin * 2), color);
    bgMargin = margin;
    reflow(FlxG.width, FlxG.height);
  }

  function onGameResized(width:Int, height:Int):Void
  {
    reflow(width, height);
  }

  function reflow(width:Int, height:Int):Void
  {
    if (width <= 0 || height <= 0) return;
    var portrait:Bool = height > width * 1.12;
    if (back != null)
    {
      var margin:Float = bgMargin ?? Math.min(MARGIN, Math.max(18, width * 0.06));
      back.makeGraphic(Std.int(Math.max(1, width - margin * 2)),
        Std.int(Math.max(1, height - margin * 2)), bgColor, false, "prompt-bg");
      back.setPosition(margin, margin);
    }

    field.scale.set(portrait ? 0.78 : 1.0, portrait ? 0.78 : 1.0);
    field.x = Math.max(12, (width - field.width * field.scale.x) * 0.5);
    field.y = portrait ? Math.max(24, height * 0.14) : MARGIN;

    var visibleButtons:Array<FlxSprite> = [];
    for (member in buttons.members)
    {
      if (member != null && member.exists) visibleButtons.push(cast member);
    }
    if (visibleButtons.length == 1)
    {
      var button:FlxSprite = visibleButtons[0];
      button.setPosition((width - button.width) * 0.5, height - button.height - (portrait ? 22 : MARGIN));
    }
    else if (visibleButtons.length > 1)
    {
      var gap:Float = portrait ? 14 : 32;
      var total:Float = 0;
      for (button in visibleButtons) total += button.width;
      total += gap * (visibleButtons.length - 1);
      var x:Float = (width - total) * 0.5;
      for (button in visibleButtons)
      {
        button.setPosition(x, height - button.height - (portrait ? 22 : MARGIN));
        x += button.width + gap;
      }
    }
  }

  override public function destroy():Void
  {
    FlxG.signals.gameResized.remove(onGameResized);
    super.destroy();
  }

  public function setButtons(style:ButtonStyle)
  {
    if (this.style != style)
    {
      this.style = style;
      createButtons();
    }
  }

  function createButtons()
  {
    // destroy previous buttons
    while (buttons.members.length > 0)
    {
      buttons.remove(buttons.members[0], true).destroy();
    }

    switch (style)
    {
      case Yes_No:
        createButtonsHelper("yes", "no");
      case Ok:
        createButtonsHelper("ok");
      case Custom(yes, no):
        createButtonsHelper(yes, no);
      case None:
        buttons.exists = false;
    };
  }

  function createButtonsHelper(yes:String, ?no:String)
  {
    buttons.exists = true;
    // pass anonymous functions rather than the current callbacks, in case they change later
    var yesButton = buttons.createItem(yes, function()
    {
      if (onYes != null) onYes();
      else
        FlxG.log.warn("onYes function was called without being set");
    });
    yesButton.screenCenter(X);
    yesButton.y = FlxG.height - yesButton.height - MARGIN;
    yesButton.scrollFactor.set(0, 0);
    if (no != null)
    {
      // place right
      yesButton.x = FlxG.width - yesButton.width - MARGIN;

      var noButton = buttons.createItem(no, function() if (onNo != null) onNo());
      noButton.x = MARGIN;
      noButton.y = FlxG.height - noButton.height - MARGIN;
      noButton.scrollFactor.set(0, 0);
    }
  }

  public function setText(text:String)
  {
    field.text = text;
    reflow(FlxG.width, FlxG.height);
  }
}

enum ButtonStyle
{
  Ok;
  Yes_No;
  Custom(yes:String, no:Null<String>); // Todo: more than 2
  None;
}
