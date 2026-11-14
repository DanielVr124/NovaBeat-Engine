function onCreate()
	
       makeAnimatedLuaSprite('minedave','minedave',-3500,-500)addAnimationByPrefix('minedave','dance','Dave',24,true)
       objectPlayAnimation('minedave','dance',false)
       setScrollFactor('minedave', 0.999, 0.999);

	addLuaSprite('minedave', false);

	close(true); --For performance reasons, close this script once the stage is fully loaded, as this script won't be used anymore after loading the stage
end