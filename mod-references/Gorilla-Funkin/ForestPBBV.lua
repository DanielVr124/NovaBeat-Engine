function onCreate()

      makeLuaSprite('foresttreepbbv', 'foresttreepbbv', -850, -630);
	setScrollFactor('foresttreepbbv', 1.0, 1.0);

      makeLuaSprite('forestbackpbbv', 'forestbackpbbv', -800, -950);
	setScrollFactor('forestbackpbbv', 1.0, 1.0);

      makeAnimatedLuaSprite('forestfrontpbbv','forestfrontpbbv',-160,-456)addAnimationByPrefix('forestfrontpbbv','dance','sexy',24,true)
      objectPlayAnimation('forestfrontpbbv','dance',false)
      setScrollFactor('forestfrontpbbv', 1.0, 1.0);

	addLuaSprite('forestbackpbbv', false);
	addLuaSprite('forestfrontpbbv', false);
      addLuaSprite('foresttreepbbv', false);

	close(true); --For performance reasons, close this script once the stage is fully loaded, as this script won't be used anymore after loading the stage
end