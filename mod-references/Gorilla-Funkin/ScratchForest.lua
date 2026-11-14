function onCreate()
	
	makeLuaSprite('scratchforest', 'scratchforest', -500, -600);
	setScrollFactor('scratchforest',  0.999, 0.999);

	addLuaSprite('scratchforest', false);

	close(true); --For performance reasons, close this script once the stage is fully loaded, as this script won't be used anymore after loading the stage
end