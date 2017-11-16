-------------  Include 
dkjson = package.loaded['game/dkjson']
-- local Q_Model = require("lua/lua/q_learning")
-- local table_print = require("lua/lua/table_print")
-- local sort_table = require("lua/lua/sort_table")
DQN = require("lua/lua/dqn")


-------------  Global Variable
-- server state
GET_MODEL_STATE = 20
UPPDATE_MODEL_STATE = 21
GET_DQN_DETAIL = 22
GET_WEIGHT = 23
GET_BIAS = 24

name_hero = "npc_dota_hero_sniper" 



-- Generated from template

if CAddonTemplateGameMode == nil then
	CAddonTemplateGameMode = class({})
end

function Precache( context )

end

-- Create the game mode when we activate
function Activate()
	GameRules.AddonTemplate = CAddonTemplateGameMode()
	GameRules.AddonTemplate:InitGameMode()
end

function CAddonTemplateGameMode:InitGameMode()
	print( "Template addon is loaded." )

	------------ Set the hero can't  level up
	local XP_PER_LEVEL_TABLE = {
        0, -- 1
  	}
    GameRules:GetGameModeEntity():SetCustomXPRequiredToReachNextLevel(XP_PER_LEVEL_TABLE)  
	GameRules:GetGameModeEntity():SetUseCustomHeroLevels(true)  	
	GameRules:GetGameModeEntity():SetCustomGameForceHero(name_hero) 	
	GameRules:GetGameModeEntity():SetFixedRespawnTime(1)

	----------- Set control creep
	SendToServerConsole( "dota_creeps_no_spawning  1" )
	SendToServerConsole( "dota_all_vision 1" )


	----------- Set Event Listener
	ListenToGameEvent( "entity_killed", Dynamic_Wrap( CAddonTemplateGameMode, 'OnEntity_kill' ), self )
	ListenToGameEvent( "player_chat", Dynamic_Wrap( CAddonTemplateGameMode, 'OnInitial' ), self ) ---- when player chat the game will reset

end

--------- Call From InitGameMode

function CAddonTemplateGameMode:InitialValue()

	goodSpawn_Radian = Entities:FindByName( nil, "npc_dota_spawner_good_mid_staging" )
	-- hero = CreateUnitByName( "npc_dota_hero_sniper" , goodSpawn_Radian:GetAbsOrigin() + RandomVector( RandomFloat( 0, 200 ) ), true, nil, nil, DOTA_TEAM_GOODGUYS )
	hero = Entities:FindByName(nil, name_hero)
	attackRangeHero = hero:GetAttackRange()
	PlayerResource:SetCameraTarget(0, hero)

	--------- get tower
	midRadianTower = Entities:FindByName (nil, "dota_goodguys_tower1_mid")
	midRadianTower:SetBaseDamageMax(30)
	midRadianTower:SetBaseDamageMin(50)
	midRadianTower:SetBaseAttackTime(0.1)

	mid2RadianTower = Entities:FindByName (nil, "dota_goodguys_tower2_mid")
	mid2RadianTower:SetBaseDamageMax(30)
	mid2RadianTower:SetBaseDamageMin(50)
	mid2RadianTower:SetBaseAttackTime(0.1)

	mid3RadianTower = Entities:FindByName (nil, "dota_goodguys_tower3_mid")

	midDireTower = Entities:FindByName (nil, "dota_badguys_tower1_mid")

	distanceBetweenRadianTower = CalcDistanceBetweenEntityOBB( midRadianTower , mid3RadianTower)
	maxDistance = CalcDistanceBetweenEntityOBB( midRadianTower , midDireTower)

	----------- set respawn position (must set every time before respawn)
	hero:SetRespawnPosition(midRadianTower:GetAbsOrigin()+ RandomVector( RandomFloat( 0, 200 )) )
	SendToServerConsole("dota_dev hero_respawn")

	self:requestActionFromServer(GET_DQN_DETAIL)
	print("Finish Reset ")

	return nil
end

function CAddonTemplateGameMode:HealthTower()
	
	midRadianTower:SetHealth( midRadianTower:GetMaxHealth()  );
	midDireTower:SetHealth( midDireTower:GetMaxHealth() );
	-- print("HealthTower")
	return 5
end


-------- State Control Function

function CAddonTemplateGameMode:TimeStepAction()
	
	local state = self:getState()
	local done = self:checkDone()	

	if(firstTime)then
		firstTime = false
	else
		reward = self:calculateReward()
		rewardEpisode = rewardEpisode + reward
		if #old_state ~= 0 then
			dqn_agent:remember( {old_state,state,state_action,reward} )
		end
		old_last_hit = 0
	end

	if(done)then
		print("reset")
		self:resetEpisode()
		-- return 0.2
	else
		diff = state[2] - state[3] -- creep - hero
		if( diff > 0.25)then
			state_action = FORWARD_ACTION_STATE

		elseif( diff <= 0)then
			state_action = BACKWARD_ACTION_STATE
		else
			state_action, predict_table = dqn_agent:act(state)
			if state[1] == -1 and state[4] == -1 then
				print("---------")
				if predict_table ~= nil then
					table_print.loop_print(predict_table)
				end
				print("++++++++")
			end		
		end	
		
		GameRules:GetGameModeEntity():SetThink( "runAction", self )
		old_state = dqn_agent:shallowcopy(state)

		return 0.2
	end

end

function CAddonTemplateGameMode:getState()
	
	local minHp_creep,minHp = self:getMinHpCreep()
	local posiHero = truePosition(hero)	
	local stateArray = {}

	if minHp_creep == nil then
		stateArray[1] = -1
		stateArray[2] = -1
	else
		stateArray[1] = normalize(minHp , 0 , minHp_creep:GetMaxHealth() )
		stateArray[2] = truePosition(minHp_creep)
	end

	stateArray[3] = posiHero

	return stateArray
end

------- Event Function

function CAddonTemplateGameMode:OnEntity_kill(event)
	local killed = EntIndexToHScript(event.entindex_killed);
	local attaker = EntIndexToHScript(event.entindex_attacker );
	local damage = event.damagebits

	if(attaker:GetName() == name_hero )then
		old_last_hit = old_last_hit + 1
		episode_last_hit = episode_last_hit + old_last_hit 
	end

	if(killed:GetName() == name_hero )then
		rewardDie = 0
		GameRules:GetGameModeEntity():SetThink( "resetEpisode", self )
	end

end

function CAddonTemplateGameMode:OnInitial()
	GameRules:GetGameModeEntity():SetThink( "InitialValue", self ,2)
	GameRules:GetGameModeEntity():SetThink( "HealthTower", self , 5)
	print("init")
end