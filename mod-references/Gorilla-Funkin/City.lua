function onCreate()
	
       makeAnimatedLuaSprite('City','City',-400,-100)addAnimationByPrefix('City','dance','gra',24,true)
       objectPlayAnimation('City','dance',false)
       setScrollFactor('City', 0.999, 0.999);
 
       makeAnimatedLuaSprite('Crowd','Crowd2',-300,450)addAnimationByPrefix('Crowd','dance','crowd',24,true)
       objectPlayAnimation('Crowd','dance',false)
       setScrollFactor('Crowd', 0.8, 0.8);

	addLuaSprite('Crowd', true);
	addLuaSprite('City', false);

	close(true); --For performance reasons, close this script once the stage is fully loaded, as this script won't be used anymore after loading the stage
end