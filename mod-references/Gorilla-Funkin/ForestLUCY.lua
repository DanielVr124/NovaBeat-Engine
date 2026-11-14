function onCreate()

       makeLuaSprite('foresttreelucy', 'foresttreelucy', -850, -630);
	setScrollFactor('foresttreelucy', 1.0, 1.0);

       makeLuaSprite('forestbacklucy', 'forestbacklucy', -800, -950);
	setScrollFactor('forestbacklucy', 1.0, 1.0);
  
       makeAnimatedLuaSprite('forestfrontlucy','forestfrontlucy',-160,-456)addAnimationByPrefix('forestfrontlucy','dance','Front',24,true)
       objectPlayAnimation('forestfrontlucy','dance',false)
       setScrollFactor('forestfrontlucy', 1.0, 1.0);

	addLuaSprite('forestbacklucy', false);
	addLuaSprite('forestfrontlucy', false);
       addLuaSprite('foresttreelucy', false);

	close(true); --For performance reasons, close this script once the stage is fully loaded, as this script won't be used anymore after loading the stage
end