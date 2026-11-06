package funkin.ui.options;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import haxe.ds.ObjectMap;
import funkin.Preferences;

/**
 * Shared NovaBeat frame for the standard Options subpages.
 * The page-specific content is kept intact and rendered above this frame.
 */
class NovaBeatOptionsChrome
{
  static var chromeByGroup:ObjectMap<FlxGroup, Array<FlxSprite>> = new ObjectMap();

  public static function apply(group:FlxGroup, pageTitle:String, camera:FlxCamera):Void
  {
    if (Preferences.menuStyle != "NovaBeat") return;

    var width:Float = FlxG.width;
    var height:Float = FlxG.height;
    var margin:Float = Math.max(20, width * 0.035);
    var panelTop:Float = 62;
    var panelHeight:Float = Math.max(120, height - panelTop - 28);
    var panelWidth:Float = Math.max(1, width - margin * 2);

    var panel:FlxSprite = new FlxSprite(margin, panelTop);
    panel.makeGraphic(Std.int(panelWidth), Std.int(panelHeight), 0xC9091833);
    panel.scrollFactor.set();
    panel.cameras = [camera];
    group.add(panel);
    var chromeElements:Array<FlxSprite> = [panel];

    var topLine:FlxSprite = new FlxSprite(margin, panelTop - 3);
    topLine.makeGraphic(Std.int(panelWidth), 3, 0xFF2879B5);
    topLine.scrollFactor.set();
    topLine.cameras = [camera];
    group.add(topLine);
    chromeElements.push(topLine);

    var leftAccent:FlxSprite = new FlxSprite(margin, panelTop);
    leftAccent.makeGraphic(3, Std.int(panelHeight), 0xFF48E7FF);
    leftAccent.scrollFactor.set();
    leftAccent.cameras = [camera];
    group.add(leftAccent);
    chromeElements.push(leftAccent);

    var brand:FlxText = new FlxText(margin + 2, 8, width * 0.55, 'NOVABEAT ENGINE', 11);
    brand.setFormat(Paths.font('vcr.ttf'), 11, 0xFF48E7FF, FlxTextAlign.LEFT);
    brand.scrollFactor.set();
    brand.cameras = [camera];
    group.add(brand);
    chromeElements.push(brand);

    var heading:FlxText = new FlxText(margin, 27, panelWidth, pageTitle, 21);
    heading.setFormat(Paths.font('vcr.ttf'), 21, FlxColor.WHITE, FlxTextAlign.LEFT);
    heading.scrollFactor.set();
    heading.cameras = [camera];
    group.add(heading);
    chromeElements.push(heading);

    var rule:FlxSprite = new FlxSprite(margin, 53);
    rule.makeGraphic(Std.int(panelWidth), 1, 0x663C8AC0);
    rule.scrollFactor.set();
    rule.cameras = [camera];
    group.add(rule);
    chromeElements.push(rule);
    chromeByGroup.set(group, chromeElements);
  }

  public static function reflow(group:FlxGroup, width:Int, height:Int):Void
  {
    var elements:Null<Array<FlxSprite>> = chromeByGroup.get(group);
    if (elements == null || elements.length < 6 || width <= 0 || height <= 0) return;

    var margin:Float = Math.max(20, width * 0.035);
    var panelTop:Float = 62;
    var panelHeight:Float = Math.max(120, height - panelTop - 28);
    var panelWidth:Float = Math.max(1, width - margin * 2);
    var portrait:Bool = height > width * 1.12;

    elements[0].setPosition(margin, panelTop);
    elements[0].makeGraphic(Std.int(panelWidth), Std.int(panelHeight), 0xC9091833);
    elements[1].setPosition(margin, panelTop - 3);
    elements[1].makeGraphic(Std.int(panelWidth), 3, 0xFF2879B5);
    elements[2].setPosition(margin, panelTop);
    elements[2].makeGraphic(3, Std.int(panelHeight), 0xFF48E7FF);

    var brand:FlxText = cast elements[3];
    brand.setPosition(margin + 2, 8);
    brand.fieldWidth = width * 0.55;

    var heading:FlxText = cast elements[4];
    heading.setPosition(margin, 27);
    heading.fieldWidth = panelWidth;
    heading.size = portrait ? 19 : 21;

    elements[5].setPosition(margin, 53);
    elements[5].makeGraphic(Std.int(panelWidth), 1, 0x663C8AC0);
  }

  public static function forget(group:FlxGroup):Void
  {
    chromeByGroup.remove(group);
  }
}
