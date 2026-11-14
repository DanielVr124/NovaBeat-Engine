function onCreate()
	
       makeAnimatedLuaSprite('forestfrontlavaangry','forestfrontlavaangry',-300,-500)addAnimationByPrefix('forestfrontlavaangry','dance','Front',24,true)
       objectPlayAnimation('forestfrontlavaangry','dance',false)
       setScrollFactor('forestfrontlavaangry', 0.999, 0.999);
    
       makeAnimatedLuaSprite('crowdanimated','Crowdlava',-350,350)addAnimationByPrefix('crowdanimated','dance','grah',24,true)
       objectPlayAnimation('crowdanimated','dance',false)
       setScrollFactor('crowdanimated', 0.5, 0.5);

       makeLuaSprite('foresttreelavaangry', 'foresttreelavaangry', -850, -630);
	setScrollFactor('foresttreelavaangry', 1.0, 1.0);

       makeLuaSprite('forestbacklavaangry', 'forestbacklavaangry', -900, -950);
       setScrollFactor('forestbacklavaangry', 1.0, 1.0);

	addLuaSprite('crowdanimated', true);
	addLuaSprite('forestbacklavaangry', false);
       addLuaSprite('foresttreelavaangry', false);
       addLuaSprite('forestfrontlavaangry', false);

	close(true);
end