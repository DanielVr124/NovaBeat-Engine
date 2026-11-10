package funkin.ui.options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxInputText;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import funkin.Preferences;
import funkin.audio.FunkinSound;
import funkin.modding.ExperienceManager;
import funkin.modding.ExperienceManager.ExperienceInfo;
import funkin.modding.PolymodHandler;
import funkin.save.Save;
import funkin.ui.Page;
import funkin.ui.title.TitleState;
import funkin.util.DeviceUtil;
import funkin.util.SwipeUtil;
import funkin.util.TouchUtil;
import polymod.Polymod.ModMetadata;
#if !web
import openfl.display.BitmapData;
#end
#if sys
import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
#end

/**
 * The single in-game mod browser.
 *
 * ExperienceManager remains responsible for package detection, ownership,
 * activation, and Polymod reloads. This class is only the player-facing UI.
 */
class ModMenu extends Page<OptionsState.OptionsMenuPageName>
{
  static inline final COLOR_BLACK:Int = 0xFF090812;
  static inline final COLOR_PANEL:Int = 0xFF241638;
  static inline final COLOR_PANEL_DARK:Int = 0xFF171024;
  static inline final COLOR_PURPLE:Int = 0xFF7545B8;
  static inline final COLOR_PINK:Int = 0xFFFF62C8;
  static inline final COLOR_BLUE:Int = 0xFF57CFFF;
  static inline final COLOR_TEXT:Int = 0xFFFFF5FF;
  static inline final COLOR_MUTED:Int = 0xFFD0C4E5;

  var experiences:Array<ExperienceInfo> = [];
  var allExperiences:Array<ExperienceInfo> = [];
  var searchQuery:String = "";
  var searchInput:Null<FlxInputText> = null;
  var mobileCountLabel:Null<FlxText> = null;
  var pendingSearchRefresh:Bool = false;
  var selectedIndex:Int = 0;
  var firstVisibleIndex:Int = 0;
  var visibleRows:Int = 1;
  var rowX:Float = 0;
  var rowY:Float = 0;
  var rowWidth:Float = 0;
  var rowHeight:Float = 58;
  var portraitLayout:Bool = false;
  var mobileDetailView:Bool = false;
  var mobileInfoY:Float = 0;
  var mobileInfoWidth:Float = 0;
  var mobileInfoHeight:Float = 0;
  var infoExpanded:Bool = false;
  var infoScroll:Int = 0;
  var lastStatus:String = "";

  var rowHitboxes:Array<FlxSprite> = [];
  var rowObjects:Array<FlxSprite> = [];
  var buttonHitboxes:Array<FlxSprite> = [];
  var buttonActions:Array<String> = [];

  var previewX:Float = 0;
  var previewY:Float = 0;
  var previewWidth:Float = 0;
  var previewHeight:Float = 0;
  var previewContentY:Float = 0;
  var previewContentHeight:Float = 0;

  public function new()
  {
    super();
    refreshModList(false);
  }

  function refreshModList(playSound:Bool = true):Void
  {
    var previousId:String = experiences.length > 0 && selectedIndex < experiences.length
      ? experiences[selectedIndex].id : "";

    allExperiences = ExperienceManager.scanInstalled().filter(function(info:ExperienceInfo):Bool
    {
      return !info.isOfficial;
    });
    allExperiences.sort(function(a:ExperienceInfo, b:ExperienceInfo):Int
    {
      return Reflect.compare(a.title.toLowerCase(), b.title.toLowerCase());
    });
    applyModSearchFilter();

    selectedIndex = 0;
    if (previousId != "")
    {
      for (index in 0...experiences.length)
      {
        if (experiences[index].id == previousId)
        {
          selectedIndex = index;
          break;
        }
      }
    }

    infoExpanded = false;
    infoScroll = 0;
    mobileDetailView = false;
    #if web
    lastStatus = "Browser builds cannot scan local mod folders. Install and browse mods in a native build.";
    #else
    lastStatus = allExperiences.length == 0
      ? "No installed mods were detected. Add a mod to the mods folder, then refresh."
      : allExperiences.length + (allExperiences.length == 1 ? " MOD INSTALLED" : " MODS INSTALLED");
    #end

    renderLayout();
    if (playSound) FunkinSound.playOnce(Paths.sound("scrollMenu"), 0.35);
  }

  function renderLayout():Void
  {
    while (members.length > 0)
      remove(members[0], true);

    rowHitboxes = [];
    rowObjects = [];
    buttonHitboxes = [];
    buttonActions = [];
    searchInput = null;
    mobileCountLabel = null;
    pendingSearchRefresh = false;

    var width:Float = FlxG.width;
    var height:Float = FlxG.height;
    portraitLayout = height > width * 1.12 || width < 520;
    var compactLandscape:Bool = !portraitLayout && height < 520;
    if (portraitLayout)
    {
      renderMobileLayout(width, height);
      return;
    }
    var margin:Float = compactLandscape ? 20 : 34;
    var headerY:Float = portraitLayout ? 12 : (compactLandscape ? 8 : 18);
    var footerHeight:Float = compactLandscape ? 38 : 48;
    var contentY:Float = portraitLayout ? 76 : (compactLandscape ? 58 : 88);
    var contentHeight:Float = Math.max(140, height - contentY - footerHeight - 14);

    addGraffitiTitle(margin, headerY, width - margin * 2);

    var listX:Float = margin;
    var listY:Float = contentY;
    var listWidth:Float;
    var listHeight:Float;
    if (portraitLayout)
    {
      listWidth = width - margin * 2;
      listHeight = Math.max(132, contentHeight * 0.39);
      previewX = margin;
      previewY = listY + listHeight + 12;
      previewWidth = listWidth;
      previewHeight = Math.max(118, contentHeight - listHeight - 12);
    }
    else
    {
      listWidth = Math.max(250, (width - margin * 2) * 0.36);
      listHeight = contentHeight;
      previewX = listX + listWidth + 14;
      previewY = listY;
      previewWidth = width - margin - previewX;
      previewHeight = contentHeight;
    }

    addPanel(listX, listY, listWidth, listHeight, COLOR_PURPLE);
    addPanel(previewX, previewY, previewWidth, previewHeight, COLOR_PINK);

    addLabel(listX + 15, listY + 12, listWidth - 30, "INSTALLED MODS", portraitLayout ? 13 : 16, COLOR_BLUE);
    var countText:String = experiences.length + (experiences.length == 1 ? " MOD INSTALLED" : " MODS INSTALLED");
    addLabel(listX + 15, listY + 34, listWidth - 30, countText, 9, COLOR_MUTED);

    rowX = listX + 10;
    rowY = listY + (compactLandscape ? 56 : 62);
    rowWidth = listWidth - 20;
    rowHeight = portraitLayout ? 52 : (compactLandscape ? 48 : 62);
    var availableRowsHeight:Float = listY + listHeight - rowY - 12;
    visibleRows = Std.int(Math.max(1, Math.floor(availableRowsHeight / rowHeight)));
    renderRows();

    buildPreview();
    buildFooter(width, height, margin, footerHeight, compactLandscape);
  }



  function mobileCountText():String
  {
    if (searchQuery.length == 0)
      return allExperiences.length + (allExperiences.length == 1 ? " INSTALLED MOD" : " INSTALLED MODS");
    return experiences.length + " OF " + allExperiences.length + " MODS MATCH";
  }

  function applyModSearchFilter():Void
  {
    var needle:String = searchQuery == null ? "" : StringTools.trim(searchQuery).toLowerCase();
    experiences = allExperiences.filter(function(info:ExperienceInfo):Bool
    {
      if (needle.length == 0) return true;
      var title:String = info.title == null ? "" : info.title.toLowerCase();
      var author:String = info.author == null ? "" : info.author.toLowerCase();
      return title.indexOf(needle) >= 0 || author.indexOf(needle) >= 0;
    });
    if (experiences.length == 0)
      selectedIndex = 0;
    else
      selectedIndex = Std.int(Math.max(0, Math.min(selectedIndex, experiences.length - 1)));
  }

  function refreshMobileSearchResults():Void
  {
    applyModSearchFilter();
    selectedIndex = 0;
    firstVisibleIndex = 0;
    mobileDetailView = false;
    infoExpanded = false;
    infoScroll = 0;
    if (mobileCountLabel != null)
      mobileCountLabel.text = mobileCountText() + "  •  TAP A CARD TO VIEW DETAILS";
    renderMobileRows();
  }

  function addMobileSearchBox(x:Float, y:Float, width:Float, height:Float):Void
  {
    var backing:FlxSprite = addRect(x, y, width, height, COLOR_PURPLE);
    buttonHitboxes.push(backing);
    buttonActions.push("focusSearch");
    addRect(x + 3, y + 3, width - 6, height - 6, COLOR_PANEL_DARK);
    if (searchQuery.length == 0)
      addLabel(x + 10, y + 9, width - 20, "SEARCH BY NAME OR CREATOR", 9, COLOR_MUTED);

    var input:FlxInputText = new FlxInputText(x + 8, y + 5, Std.int(width - 16), searchQuery,
      10, COLOR_TEXT, COLOR_PANEL_DARK, true);
    input.background = false;
    input.setFormat(Paths.font("vcr.ttf"), 10, COLOR_TEXT, FlxTextAlign.LEFT);
    input.maxLength = 48;
    input.callback = function(value:String, action:String):Void
    {
      searchQuery = value;
      pendingSearchRefresh = true;
    };
    searchInput = input;
    add(input);
  }

  /**
   * Portrait phones use a dedicated master/detail flow. The desktop list and
   * preview remain untouched; mobile never tries to squeeze both panes together.
   */
  function renderMobileLayout(width:Float, height:Float):Void
  {
    var margin:Float = Std.int(Math.max(12, Math.min(20, width * 0.045)));
    if (mobileDetailView && experiences.length > 0)
      renderMobileDetails(width, height, margin);
    else
      renderMobileList(width, height, margin);
  }

  function renderMobileList(width:Float, height:Float, margin:Float):Void
  {
    addGraffitiTitle(margin, 10, width - margin * 2);
    mobileCountLabel = addLabel(margin + 2, 52, width - margin * 2 - 4,
      mobileCountText() + "  •  TAP A CARD TO VIEW DETAILS", 9, COLOR_MUTED);

    var searchY:Float = 74;
    var clearWidth:Float = 58;
    var searchGap:Float = 8;
    var searchWidth:Float = width - margin * 2 - clearWidth - searchGap;
    addMobileSearchBox(margin, searchY, searchWidth, 32);
    addActionButton(margin + searchWidth + searchGap, searchY, clearWidth, 32,
      "CLEAR", "clearSearch", COLOR_PURPLE, false);

    var listX:Float = margin;
    var listY:Float = 114;
    var listWidth:Float = width - margin * 2;
    var footerY:Float = height - 64;
    var listHeight:Float = Math.max(96, footerY - listY - 10);

    addPanel(listX, listY, listWidth, listHeight, COLOR_PURPLE);
    rowX = listX + 10;
    rowY = listY + 14;
    rowWidth = listWidth - 20;
    rowHeight = 96;
    var availableRowsHeight:Float = listY + listHeight - rowY - 10;
    visibleRows = Std.int(Math.max(1, Math.floor(availableRowsHeight / rowHeight)));
    renderMobileRows();

    var gap:Float = 10;
    var buttonWidth:Float = (width - margin * 2 - gap) * 0.5;
    addActionButton(margin, footerY, buttonWidth, 48, "REFRESH", "refresh", COLOR_BLUE, false);
    addActionButton(margin + buttonWidth + gap, footerY, buttonWidth, 48, "BACK", "back", COLOR_PURPLE, false);
  }

  function renderMobileRows():Void
  {
    for (object in rowObjects)
      remove(object, true);
    rowObjects = [];
    rowHitboxes = [];

    if (experiences.length == 0)
    {
      var emptyTitle:String = searchQuery.length > 0 ? "NO MATCHING MODS" : "NO MODS FOUND";
      var emptyHint:String = searchQuery.length > 0
        ? "TRY ANOTHER NAME OR CLEAR YOUR SEARCH."
        : "ADD A MOD TO YOUR MODS FOLDER, THEN TAP REFRESH.";
      #if web
      if (searchQuery.length == 0)
        emptyHint = "LOCAL MOD FOLDERS ARE NOT AVAILABLE IN THE BROWSER BUILD.";
      #end
      addRowObject(addLabel(rowX + 12, rowY + 24, rowWidth - 24,
        emptyTitle, 17, COLOR_TEXT));
      addRowObject(addLabel(rowX + 12, rowY + 54, rowWidth - 24,
        emptyHint, 9, COLOR_MUTED));
      return;
    }

    if (selectedIndex < firstVisibleIndex) firstVisibleIndex = selectedIndex;
    if (selectedIndex >= firstVisibleIndex + visibleRows)
      firstVisibleIndex = selectedIndex - visibleRows + 1;
    firstVisibleIndex = Std.int(Math.max(0, Math.min(firstVisibleIndex,
      Math.max(0, experiences.length - visibleRows))));

    for (visibleIndex in 0...visibleRows)
    {
      var index:Int = firstVisibleIndex + visibleIndex;
      if (index >= experiences.length) break;

      var info:ExperienceInfo = experiences[index];
      var y:Float = rowY + visibleIndex * rowHeight;
      var cardHeight:Float = rowHeight - 8;
      var selected:Bool = index == selectedIndex;
      var card:FlxSprite = addRect(rowX, y, rowWidth, cardHeight, selected ? COLOR_PINK : 0xFF080710);
      rowHitboxes.push(card);
      addRowObject(card);
      addRowObject(addRect(rowX + 3, y + 3, rowWidth - 6, cardHeight - 6,
        selected ? 0xFF3C2859 : 0xFF21172F));

      var artSize:Float = Math.min(68, cardHeight - 12);
      var artX:Float = rowX + 9;
      var artY:Float = y + (cardHeight - artSize) * 0.5;
      var art:FlxSprite = addRect(artX, artY, artSize, artSize, 0xFF49305F);
      addRowObject(art);
      if (!loadModArtwork(art, info, artSize))
      {
        var initials:String = info.title.length <= 3
          ? info.title.toUpperCase()
          : info.title.substr(0, 3).toUpperCase();
        addRowObject(addLabel(artX + 3, artY + artSize * 0.28, artSize - 6,
          initials, 18, COLOR_PINK, FlxTextAlign.CENTER));
      }

      var textX:Float = artX + artSize + 12;
      var textWidth:Float = Math.max(1, rowWidth - (textX - rowX) - 27);
      addRowObject(addLabel(textX, y + 16, textWidth, info.title, 14, COLOR_TEXT));
      var author:String = info.author == null || info.author.length == 0
        ? "Unknown creator" : info.author;
      var state:String = info.launchable ? (info.enabled ? "READY" : "READY TO ENABLE") : "NOT LAUNCHABLE";
      addRowObject(addLabel(textX, y + 41, textWidth, author, 9, COLOR_PINK));
      addRowObject(addLabel(textX, y + 58, textWidth, state, 8,
        info.launchable ? COLOR_BLUE : COLOR_MUTED));
      addRowObject(addLabel(rowX + rowWidth - 25, y + 31, 18, "›", 22, COLOR_TEXT, FlxTextAlign.CENTER));
    }
  }

  function renderMobileDetails(width:Float, height:Float, margin:Float):Void
  {
    var info:ExperienceInfo = experiences[selectedIndex];
    addActionButton(margin, 10, 76, 42, "< BACK", "back", COLOR_PURPLE, false);
    addLabel(margin + 88, 22, width - margin * 2 - 88,
      "MOD DETAILS", 15, COLOR_PINK);

    var heroX:Float = margin;
    var heroY:Float = 62;
    var heroWidth:Float = width - margin * 2;
    var heroHeight:Float = 146;
    addPanel(heroX, heroY, heroWidth, heroHeight, COLOR_PINK);

    var artSize:Float = Math.min(94, Math.max(76, width * 0.255));
    var artX:Float = heroX + 16;
    var artY:Float = heroY + 28;
    var art:FlxSprite = addRect(artX, artY, artSize, artSize, 0xFF49305F);
    if (!loadModArtwork(art, info, artSize))
    {
      var initials:String = info.title.length <= 3
        ? info.title.toUpperCase()
        : info.title.substr(0, 3).toUpperCase();
      addLabel(artX + 4, artY + artSize * 0.29, artSize - 8,
        initials, 25, COLOR_PINK, FlxTextAlign.CENTER);
    }

    var titleX:Float = artX + artSize + 13;
    var titleWidth:Float = Math.max(70, heroX + heroWidth - titleX - 12);
    addLabel(titleX, heroY + 33, titleWidth, info.title, 16, COLOR_TEXT);
    var creator:String = info.author == null || info.author.length == 0
      ? "Unknown creator" : info.author;
    addLabel(titleX, heroY + 65, titleWidth, "BY " + creator.toUpperCase(), 9, COLOR_PINK);
    addLabel(titleX, heroY + 84, titleWidth, "VERSION " + readModVersion(info), 8, COLOR_BLUE);
    addLabel(titleX, heroY + 103, titleWidth,
      info.launchable ? (info.enabled ? "INSTALLED • ENABLED" : "INSTALLED • READY")
        : "INSTALLED • BLOCKED",
      8, info.launchable ? COLOR_MUTED : COLOR_PINK);

    var dockY:Float = height - 68;
    var contentY:Float = heroY + heroHeight + 10;
    var contentHeight:Float = Math.max(74, dockY - contentY - 10);
    addPanel(margin, contentY, heroWidth, contentHeight, COLOR_PURPLE);
    addLabel(margin + 14, contentY + 14, heroWidth - 28,
      infoExpanded ? "MOD INFORMATION" : "ABOUT THIS MOD", 10, COLOR_BLUE);

    mobileInfoY = contentY + 38;
    mobileInfoWidth = heroWidth - 28;
    mobileInfoHeight = Math.max(20, contentHeight - 78);

    var body:String = infoExpanded ? buildMoreInfo(info) : info.description;
    if (body == null || body.length == 0) body = "No description was provided.";
    var maxCharacters:Int = Std.int(Math.max(18, mobileInfoWidth / 6.5));
    var lines:Array<String> = wrapInformationLines(body, maxCharacters);
    var maxLines:Int = Std.int(Math.max(1, Math.floor(mobileInfoHeight / 14)));
    var maxScroll:Int = Std.int(Math.max(0, lines.length - maxLines));
    infoScroll = Std.int(Math.max(0, Math.min(infoScroll, maxScroll)));
    var visibleText:String = lines.slice(infoScroll, infoScroll + maxLines).join("\n");
    var bodyLabel:FlxText = addLabel(margin + 14, mobileInfoY, mobileInfoWidth,
      visibleText, 10, COLOR_MUTED);
    bodyLabel.wordWrap = false;
    bodyLabel.autoSize = false;
    bodyLabel.fieldWidth = mobileInfoWidth;
    bodyLabel.fieldHeight = mobileInfoHeight;

    if (maxScroll > 0)
    {
      addLabel(margin + 14, contentY + contentHeight - 18, heroWidth - 28,
        "SWIPE OR USE UP / DOWN TO SCROLL", 7, COLOR_BLUE);
    }

    var status:String = lastStatus;
    if (status != null && status.length > 0)
    {
      var maxStatus:Int = Std.int(Math.max(20, heroWidth / 6));
      if (status.length > maxStatus) status = status.substr(0, maxStatus - 3) + "...";
      addLabel(margin + 14, contentY + contentHeight - 32, heroWidth - 28,
        status, 7, COLOR_MUTED);
    }

    var gap:Float = 8;
    var innerWidth:Float = heroWidth - 20;
    var playWidth:Float = innerWidth * 0.62;
    var moreWidth:Float = innerWidth - playWidth - gap;
    addActionButton(margin + 10, dockY, playWidth, 52, "PLAY MOD", "play", COLOR_PINK, true);
    addActionButton(margin + 10 + playWidth + gap, dockY, moreWidth, 52,
      infoExpanded ? "LESS INFO" : "MORE INFO", "more", COLOR_PURPLE, false);
  }

  function scrollMobileDetails(direction:Int):Void
  {
    if (!mobileDetailView || experiences.length == 0) return;
    var info:ExperienceInfo = experiences[selectedIndex];
    var body:String = infoExpanded ? buildMoreInfo(info) : info.description;
    if (body == null || body.length == 0) body = "No description was provided.";
    var maxCharacters:Int = Std.int(Math.max(18, mobileInfoWidth / 6.5));
    var lineCount:Int = wrapInformationLines(body, maxCharacters).length;
    var maxLines:Int = Std.int(Math.max(1, Math.floor(mobileInfoHeight / 14)));
    var maxScroll:Int = Std.int(Math.max(0, lineCount - maxLines));
    infoScroll = Std.int(Math.max(0, Math.min(maxScroll, infoScroll + direction)));
    renderLayout();
  }

  function openMobileDetails(index:Int):Void
  {
    if (index < 0 || index >= experiences.length) return;
    selectedIndex = index;
    mobileDetailView = true;
    infoExpanded = false;
    infoScroll = 0;
    lastStatus = "SELECTED: " + experiences[index].title;
    FunkinSound.playOnce(Paths.sound("scrollMenu"), 0.35);
    renderLayout();
  }

  function addGraffitiTitle(x:Float, y:Float, width:Float):Void
  {
    var shadow:FlxText = addLabel(x + 3, y + 3, width, "MODS", 34, COLOR_BLACK);
    shadow.angle = -2;
    var title:FlxText = addLabel(x, y, width, "MODS", 34, COLOR_PINK);
    title.angle = -2;
    var subtitle:FlxText = addLabel(x + 112, y + 17, Math.max(80, width - 112),
      "PICK A MOD TO PLAY", 10, COLOR_TEXT);
    subtitle.angle = -1;
  }

  function addPanel(x:Float, y:Float, width:Float, height:Float, accent:Int):Void
  {
    addRect(x, y, width, height, COLOR_BLACK);
    addRect(x + 4, y + 4, width - 8, height - 8, COLOR_PANEL);
    var stripe:FlxSprite = addRect(x + 10, y + 10, Math.max(1, width - 20), 5, accent);
    stripe.angle = -0.6;
    addRect(x + 10, y + 18, Math.max(1, width - 20), 1, 0xFF5C4B70);
  }

  function renderRows():Void
  {
    for (object in rowObjects)
      remove(object, true);
    rowObjects = [];
    rowHitboxes = [];

    if (experiences.length == 0)
    {
      addRowObject(addLabel(rowX + 10, rowY + 10, rowWidth - 20,
        "NO MODS FOUND", 15, COLOR_TEXT));
      addRowObject(addLabel(rowX + 10, rowY + 36, rowWidth - 20,
        "Install a mod, then choose REFRESH MODS.", 10, COLOR_MUTED));
      return;
    }

    if (selectedIndex < firstVisibleIndex) firstVisibleIndex = selectedIndex;
    if (selectedIndex >= firstVisibleIndex + visibleRows)
      firstVisibleIndex = selectedIndex - visibleRows + 1;
    firstVisibleIndex = Std.int(Math.max(0, Math.min(firstVisibleIndex,
      Math.max(0, experiences.length - visibleRows))));

    for (visibleIndex in 0...visibleRows)
    {
      var index:Int = firstVisibleIndex + visibleIndex;
      if (index >= experiences.length) break;

      var info:ExperienceInfo = experiences[index];
      var y:Float = rowY + visibleIndex * rowHeight;
      var cardHeight:Float = Math.max(1, rowHeight - 6);
      var selected:Bool = index == selectedIndex;

      var hitbox:FlxSprite = addRect(rowX, y, rowWidth, cardHeight, selected ? COLOR_PINK : 0xFF080710);
      rowHitboxes.push(hitbox);
      addRowObject(hitbox);
      var inner:FlxSprite = addRect(rowX + 3, y + 3, rowWidth - 6, cardHeight - 6,
        selected ? 0xFF4A2A70 : 0xFF241A37);
      addRowObject(inner);

      var iconSize:Float = Math.min(cardHeight - 10, portraitLayout ? 40 : 48);
      var iconX:Float = rowX + 8;
      var iconY:Float = y + (cardHeight - iconSize) * 0.5;
      var iconPlate:FlxSprite = addRect(iconX, iconY, iconSize, iconSize,
        selected ? 0xFF8F4BAE : 0xFF47325C);
      addRowObject(iconPlate);

      var initials:String = info.title.length <= 3 ? info.title.toUpperCase() : info.title.substr(0, 3).toUpperCase();
      var iconLabel:FlxText = addLabel(iconX + 2, iconY + iconSize * 0.28, iconSize - 4,
        initials, portraitLayout ? 11 : 13, COLOR_TEXT, FlxTextAlign.CENTER);
      addRowObject(iconLabel);

      var labelX:Float = iconX + iconSize + 9;
      var labelWidth:Float = Math.max(1, rowWidth - (labelX - rowX) - 8);
      var titleSize:Int = portraitLayout ? 11 : 13;
      var title:FlxText = addLabel(labelX, y + 8, labelWidth,
        info.title, titleSize, selected ? COLOR_TEXT : 0xFFE4D7F3);
      addRowObject(title);

      var sub:String = info.author;
      if (sub == null || sub.length == 0) sub = "Unknown creator";
      var status:String = info.enabled ? "READY" : "DISABLED";
      var line:FlxText = addLabel(labelX, y + (portraitLayout ? 27 : 32), labelWidth,
        sub + "  •  " + status, 8, selected ? COLOR_BLUE : COLOR_MUTED);
      addRowObject(line);
    }
  }

  function buildPreview():Void
  {
    var compact:Bool = previewWidth < 520 || portraitLayout;
    var inset:Float = compact ? 12 : 20;
    var artSize:Float = compact
      ? Math.min(78, Math.max(56, previewWidth * 0.22))
      : Math.min(164, Math.max(112, previewHeight * 0.43));
    var artX:Float = previewX + inset;
    var artY:Float = previewY + inset + 8;

    addLabel(previewX + inset, previewY + 12, previewWidth - inset * 2,
      "SELECTED MOD", 9, COLOR_BLUE);

    var titleX:Float = compact ? artX + artSize + 12 : artX + artSize + 18;
    var textWidth:Float = compact
      ? Math.max(80, previewX + previewWidth - titleX - inset)
      : Math.max(80, previewX + previewWidth - titleX - inset);
    var textY:Float = artY + 2;

    if (experiences.length == 0)
    {
      addLabel(artX, artY + 12, previewWidth - inset * 2,
        "YOUR INSTALLED MODS WILL APPEAR HERE.", 13, COLOR_TEXT);
      addLabel(artX, artY + 42, previewWidth - inset * 2,
        "Use REFRESH MODS after adding a package.", 10, COLOR_MUTED);
      previewContentY = artY + artSize + 12;
      previewContentHeight = Math.max(20, previewY + previewHeight - previewContentY - 54);
    }
    else
    {
      var info:ExperienceInfo = experiences[selectedIndex];
      var art:FlxSprite = addRect(artX, artY, artSize, artSize, 0xFF080710);
      var hasArtwork:Bool = loadModArtwork(art, info, artSize);
      if (!hasArtwork)
      {
        addRect(artX + 4, artY + 4, artSize - 8, artSize - 8, 0xFF54316F);
        var initials:String = info.title.length <= 3
          ? info.title.toUpperCase()
          : info.title.substr(0, 3).toUpperCase();
        addLabel(artX + 6, artY + artSize * 0.30 + 2, artSize - 12,
          initials, compact ? 20 : 30, COLOR_BLACK, FlxTextAlign.CENTER);
        addLabel(artX + 6, artY + artSize * 0.30, artSize - 12,
          initials, compact ? 20 : 30, COLOR_PINK, FlxTextAlign.CENTER);
      }

      addLabel(titleX, textY, textWidth, info.title, compact ? 15 : 22, COLOR_TEXT);
      var creator:String = info.author == null || info.author.length == 0 ? "Unknown creator" : info.author;
      addLabel(titleX, textY + (compact ? 22 : 32), textWidth, "BY " + creator.toUpperCase(),
        compact ? 9 : 11, COLOR_PINK);
      var modVersion:String = readModVersion(info);
      addLabel(titleX, textY + (compact ? 39 : 52), textWidth,
        "VERSION " + modVersion, 8, COLOR_BLUE);

      previewContentY = Math.max(artY + artSize + 10, textY + (compact ? 55 : 72));
      previewContentHeight = Math.max(24, previewY + previewHeight - previewContentY - 78);

      var body:String = infoExpanded ? buildMoreInfo(info) : info.description;
      if (body == null || body.length == 0) body = "No description was provided.";
      if (infoExpanded)
      {
        // Keep the Play / More Info dock fixed while allowing long metadata
        // to scroll inside the preview instead of running underneath controls.
        var maxCharacters:Int = Std.int(Math.max(18, (previewWidth - inset * 2) / 8));
        var infoLines:Array<String> = wrapInformationLines(body, maxCharacters);
        var maxInfoLines:Int = Std.int(Math.max(3, Math.floor(previewContentHeight / 13)));
        var maxScroll:Int = Std.int(Math.max(0, infoLines.length - maxInfoLines));
        infoScroll = Std.int(Math.max(0, Math.min(infoScroll, maxScroll)));
        body = infoLines.slice(infoScroll, infoScroll + maxInfoLines).join("\n");
      }
      else if (body.length > (compact ? 220 : 420))
      {
        body = body.substr(0, (compact ? 217 : 417)) + "...";
      }

      var bodyLabel:FlxText = addLabel(previewX + inset, previewContentY,
        previewWidth - inset * 2, body, infoExpanded ? 9 : (compact ? 10 : 12), COLOR_MUTED);
      bodyLabel.wordWrap = true;
      bodyLabel.autoSize = false;
      bodyLabel.fieldWidth = previewWidth - inset * 2;
      bodyLabel.fieldHeight = previewContentHeight;
    }

    var statusLine:String = lastStatus;
    var maxStatusLength:Int = compact ? 46 : 90;
    if (statusLine.length > maxStatusLength)
      statusLine = statusLine.substr(0, maxStatusLength - 3) + "...";
    addLabel(previewX + inset, previewY + previewHeight - 58,
      previewWidth - inset * 2, statusLine, 7, COLOR_BLUE);

    var buttonY:Float = previewY + previewHeight - 44;
    var buttonGap:Float = 8;
    var playWidth:Float = (previewWidth - inset * 2 - buttonGap) * 0.60;
    var infoWidth:Float = previewWidth - inset * 2 - buttonGap - playWidth;
    addActionButton(previewX + inset, buttonY, playWidth, 32, "PLAY MOD", "play", COLOR_PINK, true);
    addActionButton(previewX + inset + playWidth + buttonGap, buttonY, infoWidth, 32,
      infoExpanded ? "LESS INFO" : "MORE INFO", "more", COLOR_PURPLE, false);
  }

  function buildFooter(width:Float, height:Float, margin:Float, footerHeight:Float, compactLandscape:Bool):Void
  {
    var buttonY:Float = height - footerHeight - 7;
    var buttonHeight:Float = portraitLayout ? 32 : (compactLandscape ? 27 : 34);
    var buttonGap:Float = 10;
    var buttonWidth:Float = portraitLayout
      ? (width - margin * 2 - buttonGap) / 2
      : (compactLandscape ? 116 : 144);
    addActionButton(margin, buttonY, buttonWidth, buttonHeight, "REFRESH MODS", "refresh", COLOR_BLUE, false);
    addActionButton(margin + buttonWidth + buttonGap, buttonY, buttonWidth, buttonHeight, "BACK", "back", COLOR_PURPLE, false);

    // Portrait layouts devote the footer to two full-width thumb targets.
    // Desktop / landscape can fit the richer keyboard and controller hints.
    if (!portraitLayout)
    {
      var help:String = "UP / DOWN OR D-PAD SELECT  •  ENTER / A PLAY  •  RIGHT / I INFO  •  LEFT / R REFRESH  •  ESC / B BACK  •  T CLASSIFY";
      var helpX:Float = margin + buttonWidth * 2 + 22;
      addLabel(helpX, buttonY + 9, Math.max(50, width - helpX - margin),
        help, compactLandscape ? 7 : 8, COLOR_MUTED);
    }
  }

  function addActionButton(x:Float, y:Float, width:Float, height:Float, label:String, action:String, accent:Int,
      highlighted:Bool):Void
  {
    var outer:FlxSprite = addRect(x + 2, y + 3, width, height, COLOR_BLACK);
    outer.angle = -0.6;
    var hitbox:FlxSprite = addRect(x, y, width, height, accent);
    hitbox.angle = -0.6;
    buttonHitboxes.push(hitbox);
    buttonActions.push(action);
    var inner:FlxSprite = addRect(x + 3, y + 3, Math.max(1, width - 6), Math.max(1, height - 6),
      highlighted ? 0xFF4F285E : 0xFF2B2040);
    inner.angle = -0.6;
    var text:FlxText = addLabel(x + 5, y + (height - 12) * 0.5 - 1, width - 10,
      label, height < 30 ? 8 : 10, COLOR_TEXT, FlxTextAlign.CENTER);
    text.angle = -0.6;
  }

  function addRect(x:Float, y:Float, width:Float, height:Float, color:Int):FlxSprite
  {
    var sprite:FlxSprite = new FlxSprite(x, y);
    sprite.makeGraphic(Std.int(Math.max(1, Math.ceil(width))), Std.int(Math.max(1, Math.ceil(height))), color);
    sprite.scrollFactor.set();
    add(sprite);
    return sprite;
  }

  function addLabel(x:Float, y:Float, width:Float, value:String, size:Int, color:FlxColor,
      align:FlxTextAlign = FlxTextAlign.LEFT):FlxText
  {
    var label:FlxText = new FlxText(x, y, Math.max(1, width), value, size);
    label.setFormat(Paths.font("vcr.ttf"), size, color, align);
    label.scrollFactor.set();
    add(label);
    return label;
  }

  function addRowObject(object:Dynamic):Void
  {
    if (object != null && Std.isOfType(object, FlxSprite))
      rowObjects.push(cast object);
  }

  function loadModArtwork(art:FlxSprite, info:ExperienceInfo, size:Float):Bool
  {
    #if !web
    if (info.directory == null) return false;
    for (mod in PolymodHandler.getAllMods())
    {
      if (mod.dirName != info.directory) continue;
      var iconBytes:Dynamic = Reflect.field(mod, "icon");
      if (iconBytes == null) break;
      try
      {
        var bitmap:Null<BitmapData> = BitmapData.fromBytes(cast iconBytes);
        if (bitmap != null)
        {
          art.loadGraphic(bitmap);
          var scale:Float = Math.min(size / Math.max(1, bitmap.width), size / Math.max(1, bitmap.height));
          art.setGraphicSize(Std.int(bitmap.width * scale), Std.int(bitmap.height * scale));
          art.updateHitbox();
          art.setPosition(art.x + (size - art.width) * 0.5, art.y + (size - art.height) * 0.5);
          return true;
        }
      }
      catch (error:Dynamic)
      {
        trace("Could not load mod artwork for " + info.title + ": " + Std.string(error));
      }
      break;
    }
    #end
    return false;
  }

  function readModVersion(info:ExperienceInfo):String
  {
    #if sys
    if (info.directory != null)
    {
      for (metadata in readPackageMetadataFiles(info))
      {
        var version:Dynamic = Reflect.field(metadata, "modVersion");
        if (version == null) version = Reflect.field(metadata, "version");
        if (version != null && Std.string(version).length > 0) return Std.string(version);
      }
    }
    #end
    return "NOT PROVIDED";
  }

  function buildMoreInfo(info:ExperienceInfo):String
  {
    var lines:Array<String> = [];
    lines.push("DESCRIPTION");
    lines.push(info.description == null || info.description.length == 0 ? "Not provided." : info.description);
    lines.push("");
    lines.push("CREATOR: " + (info.author == null || info.author.length == 0 ? "Not provided" : info.author));
    lines.push("MOD VERSION: " + readModVersion(info));
    lines.push("PACKAGE TYPE: " + packageTypeLabel(info.packageType));
    if (info.packageType == ExperienceManager.PACKAGE_EXTENSION)
      lines.push("LOADS WITH: " + ExperienceManager.experienceTitle(info.ownerId, allExperiences));
    lines.push("ENGINE FORMAT: " + info.engineLabel
      + (info.engineVersion == null ? "" : "  •  " + info.engineVersion));
    lines.push("PACKAGE SCAN: " + (info.launchable ? "PASSED — PACKAGE IS ELIGIBLE TO LAUNCH" : "BLOCKED"));
    if (!info.launchable && info.explanation != null && info.explanation.length > 0)
      lines.push("COMPATIBILITY NOTE: " + info.explanation);
    else if (info.engineId == "psych")
      lines.push("NOTE: A successful package scan is not a full gameplay test; advanced Psych features may still be unsupported.");

    var root:String = modRootPath(info);
    appendDetectedSection(lines, "SONGS", scanContentNames(root, ["data/songs", "songs"]));
    appendDetectedSection(lines, "CHARACTERS", scanContentNames(root, ["data/characters", "characters"]));
    appendDetectedSection(lines, "WEEKS", scanContentNames(root, ["data/weeks", "data/levels", "weeks"]));
    appendDetectedSection(lines, "STAGES", scanContentNames(root, ["data/stages", "stages"]));
    appendDetectedSection(lines, "CUSTOM EVENTS", scanContentNames(root, ["custom_events", "data/events"]));
    appendDetectedSection(lines, "CUSTOM NOTE TYPES", scanContentNames(root,
      ["custom_notetypes", "custom_note_types", "data/notetypes", "data/noteTypes"]));

    var credits:String = readPackageMetadataField(info, ["credits", "contributors", "authors"]);
    if (credits != null) lines.push("CREDITS / CONTRIBUTORS: " + credits);
    var dependencies:String = readPackageMetadataField(info, ["dependencies", "requirements"]);
    if (dependencies != null) lines.push("DEPENDENCIES / REQUIREMENTS: " + dependencies);
    var issues:String = readPackageMetadataField(info, ["knownIssues", "compatibilityIssues", "warnings"]);
    if (issues != null) lines.push("DECLARED COMPATIBILITY ISSUES: " + issues);

    if (info.enabled) lines.push("STATUS: ENABLED");
    else lines.push("STATUS: DISABLED — PLAY MOD WILL ENABLE THIS PACKAGE");

    return lines.join("\n");
  }

  function wrapInformationLines(value:String, maxCharacters:Int):Array<String>
  {
    var result:Array<String> = [];
    var safeWidth:Int = Std.int(Math.max(1, maxCharacters));

    for (paragraph in value.split("\n"))
    {
      if (paragraph.length == 0)
      {
        result.push("");
        continue;
      }

      var current:String = "";
      for (wordValue in paragraph.split(" "))
      {
        var word:String = wordValue;
        if (word.length == 0) continue;

        while (word.length > safeWidth)
        {
          if (current.length > 0)
          {
            result.push(current);
            current = "";
          }
          result.push(word.substr(0, safeWidth));
          word = word.substr(safeWidth);
        }

        if (word.length == 0) continue;
        if (current.length == 0)
          current = word;
        else if (current.length + word.length + 1 > safeWidth)
        {
          result.push(current);
          current = word;
        }
        else
        {
          current += " " + word;
        }
      }

      if (current.length > 0) result.push(current);
    }

    return result;
  }

  function appendDetectedSection(lines:Array<String>, title:String, values:Array<String>):Void
  {
    if (values.length == 0)
      lines.push(title + ": NOT DETECTED");
    else
      lines.push(title + " (" + values.length + "): " + values.join(", "));
  }

  function packageTypeLabel(value:String):String
  {
    return switch (value)
    {
      case ExperienceManager.PACKAGE_STANDALONE: "STANDALONE";
      case ExperienceManager.PACKAGE_EXTENSION: "CONTENT ADD-ON";
      default: "UNCLASSIFIED";
    };
  }

  function readPackageMetadataFiles(info:ExperienceInfo):Array<Dynamic>
  {
    var result:Array<Dynamic> = [];
    #if sys
    if (info.directory == null) return result;
    var root:String = modRootPath(info);
    for (name in ["_polymod_meta.json", "_novabeat.json", "meta.json", "pack.json"])
    {
      var path:String = Path.join([root, name]);
      if (!FileSystem.exists(path) || FileSystem.isDirectory(path)) continue;
      try
      {
        result.push(Json.parse(sys.io.File.getContent(path)));
      }
      catch (error:Dynamic)
      {
        trace("Could not parse mod metadata at " + path + ": " + Std.string(error));
      }
    }
    #end
    return result;
  }

  function readPackageMetadataField(info:ExperienceInfo, fields:Array<String>):Null<String>
  {
    #if sys
    for (metadata in readPackageMetadataFiles(info))
    {
      for (field in fields)
      {
        var value:Dynamic = Reflect.field(metadata, field);
        if (value == null) continue;
        if (Std.isOfType(value, String) && (cast value:String).length == 0) continue;
        if (Std.isOfType(value, Array))
        {
          var values:Array<Dynamic> = cast value;
          return values.map(function(entry:Dynamic):String return Std.string(entry)).join(", ");
        }
        return Std.string(value);
      }
    }
    #end
    return null;
  }

  function modRootPath(info:ExperienceInfo):String
  {
    #if sys
    if (info.directory != null) return Path.join([PolymodHandler.getModRoot(), info.directory]);
    #end
    return "";
  }

  function scanContentNames(root:String, paths:Array<String>):Array<String>
  {
    var result:Array<String> = [];
    #if sys
    if (root.length == 0) return result;
    for (relative in paths)
    {
      var directory:String = Path.join([root, relative]);
      if (!FileSystem.exists(directory) || !FileSystem.isDirectory(directory)) continue;
      for (entry in FileSystem.readDirectory(directory))
      {
        var fullPath:String = Path.join([directory, entry]);
        var name:String = entry;
        if (!FileSystem.isDirectory(fullPath))
        {
          var extension:String = Path.extension(entry).toLowerCase();
          if (extension != "json" && extension != "lua" && extension != "hscript") continue;
          name = Path.withoutExtension(entry);
        }
        if (name.length > 0 && result.indexOf(name) == -1)
          result.push(name);
      }
    }
    #end
    result.sort(Reflect.compare);
    return result;
  }

  function selectMod(index:Int):Void
  {
    if (index < 0 || index >= experiences.length || index == selectedIndex) return;
    selectedIndex = index;
    infoExpanded = false;
    infoScroll = 0;
    lastStatus = "SELECTED: " + experiences[index].title;
    FunkinSound.playOnce(Paths.sound("scrollMenu"), 0.35);
    renderLayout();
  }

  function performAction(action:String):Void
  {
    switch (action)
    {
      case "play":
        playSelectedMod();
      case "more":
        infoExpanded = !infoExpanded;
        infoScroll = 0;
        FunkinSound.playOnce(Paths.sound(infoExpanded ? "scrollMenu" : "cancelMenu"), 0.45);
        renderLayout();
      case "refresh":
        refreshModList();
      case "focusSearch":
        if (searchInput != null) searchInput.hasFocus = true;
      case "clearSearch":
        searchQuery = "";
        if (searchInput != null)
        {
          searchInput.text = "";
          searchInput.hasFocus = false;
        }
        refreshMobileSearchResults();
      case "back":
        FunkinSound.playOnce(Paths.sound("cancelMenu"));
        if (portraitLayout && mobileDetailView)
        {
          mobileDetailView = false;
          infoExpanded = false;
          infoScroll = 0;
          renderLayout();
        }
        else
        {
          onExit.dispatch();
        }
    }
  }

  function playSelectedMod():Void
  {
    if (experiences.length == 0)
    {
      lastStatus = "There are no installed mods to launch.";
      renderLayout();
      return;
    }

    var selected:ExperienceInfo = experiences[selectedIndex];
    if (!selected.launchable)
    {
      lastStatus = selected.explanation == null || selected.explanation.length == 0
        ? "This package was not marked launchable by the compatibility scan."
        : selected.explanation;
      renderLayout();
      return;
    }
    if (selected.packageType == ExperienceManager.PACKAGE_UNCLASSIFIED)
    {
      lastStatus = "This package needs a type. Press T to classify it as a standalone mod or content add-on.";
      renderLayout();
      return;
    }

    // A content add-on launches together with its assigned owner. Standalone
    // packages launch themselves. This preserves the existing package model.
    if (!selected.enabled)
      ExperienceManager.setPackageEnabled(selected);

    var targetId:String = selected.packageType == ExperienceManager.PACKAGE_EXTENSION
      ? selected.ownerId : selected.id;
    var refreshed:Array<ExperienceInfo> = ExperienceManager.scanInstalled();
    var target:Null<ExperienceInfo> = null;
    for (candidate in refreshed)
    {
      if (candidate.id == targetId)
      {
        target = candidate;
        break;
      }
    }

    if (target == null)
    {
      lastStatus = "The selected mod's launch target is no longer installed.";
      renderLayout();
      return;
    }

    if (!target.isOfficial && !target.enabled)
      ExperienceManager.setPackageEnabled(target);

    refreshed = ExperienceManager.scanInstalled();
    target = null;
    for (candidate in refreshed)
    {
      if (candidate.id == targetId)
      {
        target = candidate;
        break;
      }
    }
    if (target == null)
    {
      lastStatus = "Could not resolve the selected mod's launch target.";
      renderLayout();
      return;
    }

    var error:Null<String> = ExperienceManager.activate(target);
    if (error != null)
    {
      lastStatus = error;
      renderLayout();
      FunkinSound.playOnce(Paths.sound("cancelMenu"));
      return;
    }

    FunkinSound.playOnce(Paths.sound("confirmMenu"));
    TitleState.initialized = false;
    FlxG.switchState(() -> new TitleState());
  }

  function cycleSelectedPackageType():Void
  {
    if (experiences.length == 0) return;
    var info:ExperienceInfo = experiences[selectedIndex];
    if (info.isOfficial || info.directory == null) return;

    var nextType:String = ExperienceManager.cyclePackageType(info);
    refreshModList(false);
    for (index in 0...experiences.length)
    {
      if (experiences[index].id == info.id)
      {
        selectedIndex = index;
        infoExpanded = true;
        break;
      }
    }
    lastStatus = "PACKAGE TYPE SET TO " + packageTypeLabel(nextType);
    renderLayout();
  }

  function scrollMoreInfo(direction:Int):Void
  {
    if (!infoExpanded || experiences.length == 0) return;
    // Clamp against the available metadata lines. The preview layout computes
    // the final visible window and keeps the action dock outside the scroll area.
    var compact:Bool = previewWidth < 520 || portraitLayout;
    var inset:Float = compact ? 12 : 20;
    var maxCharacters:Int = Std.int(Math.max(18, (previewWidth - inset * 2) / 8));
    var lineCount:Int = wrapInformationLines(buildMoreInfo(experiences[selectedIndex]), maxCharacters).length;
    var artSize:Float = compact
      ? Math.min(78, Math.max(56, previewWidth * 0.22))
      : Math.min(164, Math.max(112, previewHeight * 0.43));
    var contentY:Float = Math.max(previewY + inset + 8 + artSize + 10,
      previewY + inset + 8 + (compact ? 55 : 72));
    var contentHeight:Float = Math.max(24, previewY + previewHeight - contentY - 78);
    var maxLines:Int = Std.int(Math.max(3, Math.floor(contentHeight / 13)));
    var maxScroll:Int = Std.int(Math.max(0, lineCount - maxLines));
    infoScroll = Std.int(Math.max(0, Math.min(maxScroll, infoScroll + direction)));
    renderLayout();
  }

  function pointerOverAt(sprite:FlxSprite, pointer:Dynamic):Bool
  {
    if (sprite == null || pointer == null) return false;

    // Resolve touch and compatibility-mouse pointers into the sprite camera's
    // world space. This avoids the HTML5 touch overlap mismatch on scaled views.
    var worldPoint:FlxPoint = pointer.getWorldPosition(sprite.camera);
    if (worldPoint == null) return false;

    var isOver:Bool = sprite.overlapsPoint(worldPoint, true, sprite.camera);
    worldPoint.putWeak();
    return isOver;
  }

  function handlePointerInput():Void
  {
    var touchReleased:Bool = TouchUtil.justReleased;
    var mouseReleased:Bool = FlxG.mouse.justReleased;
    if (!touchReleased && !mouseReleased) return;

    var touchPointer:Dynamic = TouchUtil.touch;
    var mousePointer:Dynamic = FlxG.mouse;

    for (index in 0...buttonHitboxes.length)
    {
      var hitbox:FlxSprite = buttonHitboxes[index];
      var overTouch:Bool = touchReleased && pointerOverAt(hitbox, touchPointer);
      var overMouse:Bool = mouseReleased && pointerOverAt(hitbox, mousePointer);
      if (overTouch || overMouse)
      {
        performAction(buttonActions[index]);
        return;
      }
    }

    for (index in 0...rowHitboxes.length)
    {
      var hitbox:FlxSprite = rowHitboxes[index];
      var overTouch:Bool = touchReleased && pointerOverAt(hitbox, touchPointer);
      var overMouse:Bool = mouseReleased && pointerOverAt(hitbox, mousePointer);
      if (overTouch || overMouse)
      {
        if (portraitLayout)
          openMobileDetails(firstVisibleIndex + index);
        else
          selectMod(firstVisibleIndex + index);
        return;
      }
    }
  }

  override function updateEnabled(elapsed:Float):Void
  {
    if (!enabled) return;

    if (pendingSearchRefresh)
    {
      pendingSearchRefresh = false;
      if (portraitLayout && !mobileDetailView)
        refreshMobileSearchResults();
    }

    // While the search field owns keyboard focus, do not let menu navigation
    // consume typed characters or launch the currently highlighted package.
    if (searchInput != null && searchInput.hasFocus)
    {
      // Still allow the clear, refresh, card, and back targets to receive
      // taps while the software keyboard is open.
      handlePointerInput();
      if (searchInput != null && searchInput.hasFocus)
      {
        if (controls.BACK_P || FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.ENTER)
          searchInput.hasFocus = false;
        return;
      }
    }

    // Handle keyboard and controller Back exactly once. This Page subclass
    // owns its Back action so the base Page implementation cannot dispatch
    // a duplicate exit during the same frame.
    if (controls.BACK_P || FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE)
    {
      performAction("back");
      return;
    }

    handlePointerInput();

    if (FlxG.mouse.deltaWheel.y != 0)
    {
      if (infoExpanded)
        scrollMoreInfo(FlxG.mouse.deltaWheel.y < 0 ? 3 : -3);
      else
        selectMod(selectedIndex + (FlxG.mouse.deltaWheel.y < 0 ? 1 : -1));
    }

    if (portraitLayout && mobileDetailView)
    {
      if (controls.UI_UP_P || FlxG.keys.justPressed.UP || SwipeUtil.swipeUp)
        scrollMobileDetails(-3);
      if (controls.UI_DOWN_P || FlxG.keys.justPressed.DOWN || SwipeUtil.swipeDown)
        scrollMobileDetails(3);
      if (controls.UI_LEFT_P || FlxG.keys.justPressed.LEFT)
      {
        performAction("back");
        return;
      }
      if (controls.UI_RIGHT_P || FlxG.keys.justPressed.I)
        performAction("more");
    }
    else if (infoExpanded)
    {
      if (controls.UI_UP_P || FlxG.keys.justPressed.UP || SwipeUtil.swipeUp) scrollMoreInfo(-3);
      if (controls.UI_DOWN_P || FlxG.keys.justPressed.DOWN || SwipeUtil.swipeDown) scrollMoreInfo(3);
      if (controls.UI_LEFT_P || FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.I)
      {
        infoExpanded = false;
        infoScroll = 0;
        renderLayout();
      }
    }
    else
    {
      if (controls.UI_UP_P || FlxG.keys.justPressed.UP || SwipeUtil.swipeUp)
        selectMod(selectedIndex - 1);
      if (controls.UI_DOWN_P || FlxG.keys.justPressed.DOWN || SwipeUtil.swipeDown)
        selectMod(selectedIndex + 1);
      if (controls.UI_RIGHT_P || FlxG.keys.justPressed.I)
        performAction("more");
      if (controls.UI_LEFT_P)
        refreshModList();
    }

    if (controls.ACCEPT_P || FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
      playSelectedMod();
    if (FlxG.keys.justPressed.R)
      refreshModList();
    if (FlxG.keys.justPressed.T)
      cycleSelectedPackageType();
  }

  override public function onViewportResize(width:Int, height:Int):Void
  {
    super.onViewportResize(width, height);
    if (width > 0 && height > 0) renderLayout();
  }
}

