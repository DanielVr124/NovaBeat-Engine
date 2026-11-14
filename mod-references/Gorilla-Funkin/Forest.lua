function onCreate()
	
	makeLuaSprite('forestfront', 'forestfront', -160, -456);
	setScrollFactor('forestfront',  1.0, 1.0);

      makeLuaSprite('foresttree', 'foresttree', -850, -630);
	setScrollFactor('foresttree', 1.0, 1.0);

       makeLuaSprite('forestback', 'forestback', -900, -950);
	setScrollFactor('forestback', 1.0, 1.0);

	addLuaSprite('forestback', false);
	addLuaSprite('forestfront', false);
      addLuaSprite('foresttree', false);

	close(true); --For performance reasons, close this script once the stage is fully loaded, as this script won't be used anymore after loading the stage
end