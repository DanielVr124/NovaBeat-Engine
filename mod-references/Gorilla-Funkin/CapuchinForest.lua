function onCreate()
	
	makeLuaSprite('CapuchinFence', 'CapuchinFence', 760, 650);
	setScrollFactor('CapuchinFence',  1.0, 1.0);

	makeLuaSprite('CapuchinFront', 'CapuchinFront', -900, 300);
	setScrollFactor('CapuchinFront',  1.0, 1.0);

      makeLuaSprite('CapuchinBack', 'CapuchinBack', -400, 0);
	setScrollFactor('CapuchinBack', 0.99, 0.99);

       makeLuaSprite('CapuchinFarBack', 'CapuchinFarBack', -400, -500);
	setScrollFactor('CapuchinFarBack', 0.6, 0.6);

	addLuaSprite('CapuchinFarBack', false);
       addLuaSprite('CapuchinBack', false);
       addLuaSprite('CapuchinFront', false);
       addLuaSprite('CapuchinFence', true);

	close(true); --For performance reasons, close this script once the stage is fully loaded, as this script won't be used anymore after loading the stage
end