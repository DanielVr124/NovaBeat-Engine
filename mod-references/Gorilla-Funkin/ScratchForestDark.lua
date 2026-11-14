function onCreate()
	
	makeLuaSprite('scratchforestdark', 'scratchforestdark', -500, -600);
	setScrollFactor('scratchforestdark',  0.999, 0.999);

	addLuaSprite('scratchforestdark', false);

	close(true); --For performance reasons, close this script once the stage is fully loaded, as this script won't be used anymore after loading the stage
end