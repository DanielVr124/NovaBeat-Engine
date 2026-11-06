package funkin.ui.charSelect;

import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import funkin.graphics.FunkinSprite;
import flixel.util.FlxColor;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.play.components.HealthIcon;
import funkin.ui.freeplay.charselect.PlayableCharacter;
import funkin.data.freeplay.player.PlayerRegistry;
import funkin.ui.mainmenu.MainMenuState;
#if mobile
import funkin.util.TouchUtil;
import funkin.util.DeviceUtil;
#end

using flixel.util.FlxSpriteUtil;

/**
 * When you want the player to unlock a character, call `CharacterUnlockState.unlock(characterName)`.
 * It handles both the act of unlocking the character and displaying the dialog.
 */
@:nullSafety
class CharacterUnlockState extends MusicBeatState
{
  public var targetCharacterId:String = "";
  public var targetCharacterData:Null<PlayableCharacter>;

  var nextState:FlxState;

  static final DIALOG_BG_COLOR:FlxColor = 0xFF000000; // Iconic
  static final DIALOG_COLOR:FlxColor = 0xFF4344F6; // Iconic
  static final DIALOG_FONT_COLOR:FlxColor = 0xFFFFFFFF; // Iconic

  var busy:Bool = false;
  var dialogContainer:Null<FlxSpriteGroup> = null;
  var dialogBackground:Null<FlxSprite> = null;
  var dialogText:Null<FlxText> = null;
  var healthIcon:Null<HealthIcon> = null;

  public function new(targetPlayableCharacter:String, ?nextState:FlxState)
  {
    super();

    this.targetCharacterId = targetPlayableCharacter;
    this.targetCharacterData = PlayerRegistry.instance.fetchEntry(targetCharacterId);
    this.nextState = nextState == null ? new MainMenuState() : nextState;
  }

  override function create():Void
  {
    super.create();

    handleMusic();

    bgColor = DIALOG_BG_COLOR;

    var dialogContainer:FlxSpriteGroup = new FlxSpriteGroup();
    this.dialogContainer = dialogContainer;
    add(dialogContainer);

    // Build the graphic for the text...
    var charName:String = targetCharacterData != null ? targetCharacterData.getName() : targetCharacterId.toTitleCase();
    // var dialogText:FlxText = new FlxText(0, 0, 0, 'You can now play as     $charName.\n\nCheck it out in Freeplay!');
    var dialogText:FlxText = new FlxText(0, 0, 0, 'You can now play as     $charName.');
    dialogText.setFormat("VCR OSD Mono", 32, DIALOG_FONT_COLOR, LEFT);
    this.dialogText = dialogText;

    // THEN we can size the dialog to match...
    var dialogBG:FlxSprite = new FlxSprite(0, 0);
    this.dialogBackground = dialogBG;
    dialogBG.makeGraphic(Std.int(dialogText.width + 32), Std.int(dialogText.height + 32), FlxColor.TRANSPARENT);
    dialogBG.drawRoundRect(0, 0, dialogBG.width, dialogBG.height, 16, 16, DIALOG_COLOR);
    dialogContainer.add(dialogBG);

    dialogBG.screenCenter(XY);

    // THEN we can position the text inside that.
    dialogText.x = dialogBG.x + 16;
    dialogText.y = dialogBG.y + 16;
    dialogContainer.add(dialogText);

    // HealthIcon handles getting the right frames for us,
    // but it has a bunch of overhead in it that makes it gross to work with outside the health bar.
    var healthIconCharacterId = targetCharacterData?.getOwnedCharacterIds()[0];
    var baseCharacter = CharacterDataParser.fetchCharacter(healthIconCharacterId ?? Constants.DEFAULT_CHARACTER);
    var healthIcon:HealthIcon = new HealthIcon(healthIconCharacterId);
    this.healthIcon = healthIcon;
    @:privateAccess
    healthIcon.configure(baseCharacter?._data.healthIcon);
    healthIcon.autoUpdate = false;
    healthIcon.bopEvery = 0; // You can increase this number later once the animation is done.
    healthIcon.size.set(0.5, 0.5);
    healthIcon.x = dialogBG.x + 390;
    healthIcon.y = dialogBG.y + 6;
    healthIcon.flipX = true;
    healthIcon.snapToTargetSize();
    dialogContainer.add(healthIcon);

    dialogContainer.scale.set(0, 0);
    FlxTween.num(0.0, 1.0, 0.75, {
      ease: FlxEase.elasticOut,
    }, function(curScale)
    {
      dialogContainer.scale.set(curScale, curScale);
      healthIcon.size.set(0.5 * curScale, 0.5 * curScale);
    });

    // performUnlock();
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (dialogContainer == null || dialogBackground == null || dialogText == null || healthIcon == null) return;
    var portrait:Bool = height > width * 1.12;
    var margin:Float = portrait ? 20 : 64;
    var iconSpace:Float = portrait ? 0 : 190;
    var maxWidth:Float = Math.max(120, width - margin * 2);
    dialogText.fieldWidth = Math.max(120, maxWidth - 32 - iconSpace);
    dialogText.size = portrait ? 21 : 32;
    dialogText.wordWrap = true;

    var panelWidth:Int = Std.int(Math.min(maxWidth, dialogText.width + 32 + iconSpace));
    var panelHeight:Int = Std.int(dialogText.height + 32);
    dialogBackground.makeGraphic(panelWidth, panelHeight, FlxColor.TRANSPARENT);
    dialogBackground.drawRoundRect(0, 0, panelWidth, panelHeight, 16, 16, DIALOG_COLOR);
    dialogBackground.updateHitbox();
    dialogBackground.screenCenter(XY);
    dialogText.setPosition(dialogBackground.x + 16, dialogBackground.y + 16);
    healthIcon.visible = !portrait;
    healthIcon.setPosition(dialogBackground.x + dialogBackground.width - healthIcon.width - 12,
      dialogBackground.y + (dialogBackground.height - healthIcon.height) * 0.5);
    dialogContainer.setPosition(0, 0);
  }

  function handleMusic():Void
  {
    FlxG.sound.music?.stop();
    FlxG.sound.play(Paths.sound('confirmMenu'));
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (controls.ACCEPT_P || controls.BACK_P #if mobile || TouchUtil.pressAction() #end && !busy)
    {
      busy = true;
      startClose();
    }
  }

  function startClose():Void
  {
    // Fade to black, then switch state.
    FlxG.camera.fade(FlxColor.BLACK, 0.75, false, () ->
    {
      funkin.FunkinMemory.clearFreeplay();
      #if ios
      trace(DeviceUtil.iPhoneNumber);
      if (DeviceUtil.iPhoneNumber > 12) funkin.FunkinMemory.purgeCache(true);
      else
        funkin.FunkinMemory.purgeCache();
      #else
      funkin.FunkinMemory.purgeCache(true);
      #end
      FlxG.switchState(() -> nextState);
    });
  }
}
