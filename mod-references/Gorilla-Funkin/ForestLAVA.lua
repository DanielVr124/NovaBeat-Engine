function onCreate()
	
      makeAnimatedLuaSprite('forestfrontlava','forestfrontlava',-160,-456)addAnimationByPrefix('forestfrontlava','dance','Front',24,true)
      objectPlayAnimation('forestfrontlava','dance',false)
      setScrollFactor('forestfrontlava', 0.999, 0.999);

      makeLuaSprite('foresttreelava', 'foresttreelava', -850, -630);
	setScrollFactor('foresttreelava', 1.0, 1.0);

      makeAnimatedLuaSprite('crowdanimated','Crowd',-350,350)addAnimationByPrefix('crowdanimated','dance','grah',24,true)
      objectPlayAnimation('crowdanimated','dance',false)
      setScrollFactor('crowdanimated', 0.5, 0.5);

     makeLuaSprite('forestbacklava', 'forestbacklava', -900, -950);
	setScrollFactor('forestbacklava', 1.0, 1.0);

	addLuaSprite('forestbacklava', false);
	addLuaSprite('forestfrontlava', false);
      addLuaSprite('foresttreelava', false);
      addLuaSprite('crowdanimated', true);

	close(true);
end