-------------  Include
dkjson = package.loaded['game/dkjson']
-- local Q_Model = require("lua/lua/q_learning")
local table_print = require("lua/lua/table_print")
-- local sort_table = require("lua/lua/sort_table")
DQN = require("lua/lua/dqn")

if CAddonTemplateGameMode == nil then
	CAddonTemplateGameMode = class({})
end
-------------  Global Variable

-- action state
IDLE_ACTION_STATE = 1
FORWARD_ACTION_STATE = 2
BACKWARD_ACTION_STATE = 3
LASTHIT_ACTION_STATE = 4
DENY_ACTION_STATE = 5

-- server state
GET_MODEL_STATE = 20
UPPDATE_MODEL_STATE = 21
GET_DQN_DETAIL = 22
GET_WEIGHT = 23
GET_BIAS = 24

--- weight
lasthit_reward_weight = 1
kill_reward_weight = 10
decrease_episode_reward = 0

name_hero = "npc_dota_hero_sniper"
dqn_agent = nil
hero_list = {} -- GOODGUY(2),BADGUY(3)


state_action = 1


-- Generated from template



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

	CreateUnitByName( name_hero ,  RandomVector( RandomFloat( 0, 200 ) ), true, nil, nil, DOTA_TEAM_BADGUYS )

	----------- Set control creep
	SendToServerConsole( "dota_creeps_no_spawning  1" )
	SendToServerConsole( "dota_all_vision 1" )


	----------- Set Event Listener
	ListenToGameEvent( "entity_killed", Dynamic_Wrap( CAddonTemplateGameMode, 'OnEntity_kill' ), self )
	ListenToGameEvent( "player_chat", Dynamic_Wrap( CAddonTemplateGameMode, 'OnInitial' ), self ) ---- when player chat the game will reset


end

---------- Call From InitGameMode

function CAddonTemplateGameMode:InitialValue()

	

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

	--------- Hero Find
	hero = Entities:FindByName(nil, name_hero)	
	allHero =  Entities:FindAllByName(name_hero)
	for idx,hero in pairs( allHero ) do
		if hero:GetTeam() == DOTA_TEAM_GOODGUYS then
			hero_list[1] = hero
		else	
			hero_list[2] = hero
		end
	end

	--------- Hero Properties	
	attackRangeHero = hero:GetAttackRange()
	-- PlayerResource:SetCameraTarget(0, hero)
	

	distanceBetweenRadianTower = CalcDistanceBetweenEntityOBB( midRadianTower, mid3RadianTower)
	maxDistance = CalcDistanceBetweenEntityOBB( midRadianTower, midDireTower)

	----------- set respawn position (must set every time before respawn)
	-- hero_list[1]:SetRespawnPosition(midRadianTower:GetAbsOrigin() + RandomVector( RandomFloat( 0, 200 )) )
	-- hero_list[2]:SetRespawnPosition(midRadianTower:GetAbsOrigin() + RandomVector( RandomFloat( 0, 200 )) )
	-- SendToServerConsole("dota_dev hero_respawn")
	self:resetThing()
	
	-- co = coroutine.create(function ()
	-- 	print("hi")
	--   end)

	-- print(co)
	-- coroutine.resume(co)
	
	GameRules:GetGameModeEntity():SetThink( "SpawnCreep", self)
	self:requestActionFromServer(GET_DQN_DETAIL)
	
	print("Finish Reset ")

	return nil
end

function CAddonTemplateGameMode:HealthTower()

	midRadianTower:SetHealth( midRadianTower:GetMaxHealth() );
	midDireTower:SetHealth( midDireTower:GetMaxHealth() );
	-- print("HealthTower")
	return 5
end

---------- Connect Server Function
function CAddonTemplateGameMode:requestActionFromServer(method, input)
	input = input or {}
	local dataSend = {}
	dataSend['method'] = method

	if dataSend['method'] == GET_DQN_DETAIL then
		print("send detail")

	elseif dataSend['method'] == GET_WEIGHT then
		dataSend['layer'] = input[1]
		dataSend['row'] = input[2]

	elseif dataSend['method'] == GET_BIAS then
		dataSend['layer'] = input[1]

	elseif dataSend['method'] == UPPDATE_MODEL_STATE then
		print("update model")
		dataSend['mem_episode'] = dqn_agent.memory

	end


	request = CreateHTTPRequestScriptVM("POST", "http://localhost:8080" )
	request:SetHTTPRequestHeaderValue("Accept", "application/json")
	request:SetHTTPRequestRawPostBody('application/json', dkjson.encode(dataSend))

	request:Send( function( result )

		if result["StatusCode"] == 200 then
		dict_value = dkjson.decode(result['Body'])

		if dataSend['method'] == GET_DQN_DETAIL then
			local input = dict_value['num_input']
			local output = dict_value['num_output']
			local hidden_layer = dict_value['list_hidden']
			print( result['Body'] )
			dqn_agent = DQN.new(input, output, hidden_layer)
			print("get model")
			GameRules:GetGameModeEntity():SetThink( "GetDQN_Model", self, 3)

		elseif dataSend['method'] == GET_WEIGHT then
			num_layer = dataSend['layer']
			row = dataSend['row']
			dqn_agent.weight_array[num_layer][row] = dict_value['weight']

		elseif dataSend['method'] == GET_BIAS then
			num_layer = dataSend['layer']
			dqn_agent.bias_array[num_layer] = dict_value['bias']
			if num_layer == 1 then
				table_print.loop_print( dqn_agent.bias_array[num_layer] )
			end
			if num_layer == dqn_agent.total_weight_layer then
				-- self:resetThing()
				-- GameRules:GetGameModeEntity():SetThink( "TimeStepAction", self, 2)

				
				old_state[1] = self:getState(1)
				-- old_state[2] = self:getState(2)
				GameRules:GetGameModeEntity():SetThink( "runAgent1", self )
			end

		elseif dataSend['method'] == UPPDATE_MODEL_STATE then
			dqn_agent.memory = {}
			print("startt")
			self:GetDQN_Model()
			print("finishhh")

		end

	end

	end )
end

function CAddonTemplateGameMode:GetDQN_Model()
	local temp_table = dqn_agent.hidden_layer
	table_print.loop_print(temp_table)
	for layer = 1, #temp_table do
		for row = 1, temp_table[layer] do
			self:requestActionFromServer(GET_WEIGHT, {layer, row})
		end
	end

	for layer = 1, #temp_table do
		self:requestActionFromServer(GET_BIAS, {layer})

	end

end

---------- State Control Function
old_state = {}
kill_score = {0,0}
action = {0,0}
old_last_hit = {0,0}
rewardEpisode = 0
episode_last_hit = 0
countEpisode = 0
resetEpisodeReward = 0
can_run_step = true


function CAddonTemplateGameMode:resetEpisode2()

	self:ForceKillCreep(creeps_Radian)
	self:ForceKillCreep(creeps_Dire)

	self:requestActionFromServer(UPPDATE_MODEL_STATE)
	self:resetThing()
	kill_score = {0,0}
	old_last_hit = {0,0}

	old_state[1] = self:getState(1)
	old_state[2] = self:getState(2)

	GameRules:GetGameModeEntity():SetThink( "runAgent1", self )
	-- GameRules:GetGameModeEntity():SetThink( "runAgent2", self )
	
	can_run_step = true
end

function CAddonTemplateGameMode:runAgent1()	
	if can_run_step then
		local predict_table = {}
		-- table_print.loop_print( old_state[1] )
		action[1], predict_table = dqn_agent:act(old_state[1])
		self:runEnvironment(1, action[1])
	end
end

function CAddonTemplateGameMode:update_mem_and_reward1()
	self:update_mem_and_reward(1)
	GameRules:GetGameModeEntity():SetThink( "runAgent1", self )
end 

function CAddonTemplateGameMode:update_mem_and_reward(num_hero)
	-- print("dddddssss")
	local reward = self:calculateReward(num_hero)
	local done = not can_run_step
	if done then
		print("----")
		table_print.loop_print( old_state[num_hero] )
	end
	local new_state = self:getState(num_hero)
	dqn_agent:remember( {old_state[num_hero], new_state, action[num_hero], reward, done} )
	old_state[num_hero] = new_state
end

function CAddonTemplateGameMode:getState(num_hero)
	local creeps = {}
	if num_hero == 1 then
		creeps = creeps_Dire
	else
		creeps = creeps_Radian
	end
	
	local minHp_creep, minHp = self:getMinHpCreep(creeps)
	local posiHero = truePosition(hero_list[num_hero])
	local stateArray = {}

	if minHp_creep == nil then
		stateArray[1] = -1
		stateArray[2] = -1
	else
		stateArray[1] = normalize(minHp, 0, minHp_creep:GetMaxHealth() )
		stateArray[2] = truePosition(minHp_creep)
	end

	stateArray[3] = posiHero

	return stateArray
end

function CAddonTemplateGameMode:checkDone()
	local countCreepDieDire = 0
	local countCreepDieRadian = 0

	----------- Count die creep number
	for i = 1, #creeps_Dire do
		if(creeps_Dire[i]:IsNull() or creeps_Dire[i]:IsAlive() == false )then
			countCreepDieDire = countCreepDieDire + 1
		end
	end

	for i = 1, #creeps_Radian do
		if(creeps_Radian[i]:IsNull() or creeps_Radian[i]:IsAlive() == false )then
			countCreepDieRadian = countCreepDieRadian + 1
		end
	end

	------------- Reset the episode when all dire creep are die
	if(countCreepDieDire == #creeps_Dire)then
		resetEpisodeReward = 0
		return true
	end

	------------ When Hero is going to die, Reset the episode
	if hero:GetHealth() < 50 then
		resetEpisodeReward = 0
		return true
	end

	return false
end

function CAddonTemplateGameMode:calculateReward(num_hero)

	-- min_distance_creep, min_distance = self:getMinDistanceCreep(false)
	-- distance = CalcDistanceBetweenEntityOBB(min_distance_creep, hero);
	-- rewardAttackRange = 0
	-- if( distance >= attackRangeHero + 300)then
	-- 	rewardAttackRange = -1
	-- else
	-- 	rewardAttackRange = 1
	-- end

	return kill_score[num_hero] * kill_reward_weight + old_last_hit[num_hero] * lasthit_reward_weight 

end


function CAddonTemplateGameMode:resetThing()
	--------- Spawn Hero
	FindClearSpaceForUnit(hero_list[1], midRadianTower:GetAbsOrigin() + RandomVector( RandomFloat( 0, 200 )) , true)
	FindClearSpaceForUnit(hero_list[2], midDireTower:GetAbsOrigin() + RandomVector( RandomFloat( 0, 200 )), true)

end

function CAddonTemplateGameMode:callRe()
	GameRules:GetGameModeEntity():SetThink( "TimeStepAction", self )
end

function CAddonTemplateGameMode:doStop2()
	if(state_action == IDLE_ACTION_STATE)then
		-- print("dostop")
		hero:Stop()
		GameRules:GetGameModeEntity():SetThink( "doStop", self, 0.1 )
	end
end

function CAddonTemplateGameMode:doStop()
	if(state_action == IDLE_ACTION_STATE)then
		-- print("dostop")
		hero:Stop()
		GameRules:GetGameModeEntity():SetThink( "doStop2", self, 0.1 )
	end
end

function CAddonTemplateGameMode:runEnvironment(num_hero, action)
	-- print("action :"..action)
	if(action == IDLE_ACTION_STATE)then
		-- print("IDLE")
		-- GameRules:GetGameModeEntity():SetThink( "doStop", self )
		hero_list[num_hero]:Stop()
		GameRules:GetGameModeEntity():SetThink( "update_mem_and_reward1", self , 0.2)

	elseif(action == FORWARD_ACTION_STATE)then
		-- print("FORWARD")
		hero_list[num_hero]:Stop()
		hero:MoveToNPC(midDireTower)
		GameRules:GetGameModeEntity():SetThink( "update_mem_and_reward1", self , 0.2)
	elseif(action == BACKWARD_ACTION_STATE)then
		-- print("BACKWARD")
		hero_list[num_hero]:Stop()
		hero_list[num_hero]:MoveToNPC(mid3RadianTower)
		GameRules:GetGameModeEntity():SetThink( "update_mem_and_reward1", self , 0.2)

	elseif(action == LASTHIT_ACTION_STATE)then
		-- print("LASTHIT")
		local minHp_creep, minHp = self:getMinHpCreep()
		hero_list[num_hero]:Stop()
		
		local distance = CalcDistanceBetweenEntityOBB(minHp_creep, hero);
		if( distance <= attackRangeHero )then
			hero:MoveToTargetToAttack(minHp_creep)
		end

		GameRules:GetGameModeEntity():SetThink( "update_mem_and_reward1", self , 0.5)

	elseif(action == DENY_ACTION_STATE)then
		-- print("DENY")
		minHp_creep, minHp = self:getMinHpCreep(creeps_Radian)
		hero_list[num_hero]:Stop()
		hero_list[num_hero]:MoveToTargetToAttack(minHp_creep)
		-- GameRules:GetGameModeEntity():SetThink( "TimeStepAction", self, 0.4)
	end
	
end


------- Event Function

function CAddonTemplateGameMode:OnEntity_kill(event)
	local killed = EntIndexToHScript(event.entindex_killed);
	local attaker = EntIndexToHScript(event.entindex_attacker );
	local damage = event.damagebits

	if(attaker:GetName() == name_hero )then
		old_last_hit[attaker:GetTeam()-1] = 1
		episode_last_hit = episode_last_hit + 1
	end

	if(killed:GetName() == name_hero )then
		rewardDie = 0

		kill_score[killed:GetTeam()-1] = 1
			
		can_run_step = false
		-- self:resetEpisode2()
		GameRules:GetGameModeEntity():SetThink( "resetEpisode2", self, 3)

	end

end

function CAddonTemplateGameMode:OnInitial()

	self:InitialValue()
	-- GameRules:GetGameModeEntity():SetThink( "HealthTower", self, 5)
	print("init")
end

--------- Creep Function
function CAddonTemplateGameMode:SpawnCreep()
	self:CreateCreep()
	return 30
end

function CAddonTemplateGameMode:CreateCreep()

	--------------- Create Radian Creep
	local goodSpawn_Radian = midRadianTower
	local goodWP_Radian = Entities:FindByName ( nil, "lane_mid_pathcorner_goodguys_1")
	creeps_Radian = {}
	for i = 1, 3 do
		creeps_Radian[i] = CreateUnitByName( "npc_dota_creep_goodguys_melee", goodSpawn_Radian:GetAbsOrigin() + RandomVector( RandomFloat( 0, 200 ) ), true, nil, nil, DOTA_TEAM_GOODGUYS )
	end
	creeps_Radian[4] = CreateUnitByName( "npc_dota_creep_goodguys_ranged" , goodSpawn_Radian:GetAbsOrigin() + RandomVector( RandomFloat( 0, 200 ) ), true, nil, nil, DOTA_TEAM_GOODGUYS )
	for i = 1, 4 do
		creeps_Radian[i]:SetInitialGoalEntity( goodWP_Radian )
		print(creeps_Radian[i]:GetName())
	end


	--------------- Create Dire Creep
	local goodSpawn_Dire = midDireTower
	local goodWP_Dire = Entities:FindByName ( nil, "lane_mid_pathcorner_badguys_1")
	creeps_Dire = {}
	for i = 1, 3 do
		creeps_Dire[i] = CreateUnitByName( "npc_dota_creep_goodguys_melee", goodSpawn_Dire:GetAbsOrigin() + RandomVector( RandomFloat( 0, 200 ) ), true, nil, nil, DOTA_TEAM_BADGUYS )

	end
	creeps_Dire[4] = CreateUnitByName( "npc_dota_creep_goodguys_ranged" , goodSpawn_Dire:GetAbsOrigin() + RandomVector( RandomFloat( 0, 200 ) ), true, nil, nil, DOTA_TEAM_BADGUYS )
	local randomNum = RandomInt(1, 10)
	for i = 1, 4 do
		creeps_Dire[i]:SetInitialGoalEntity( goodWP_Dire )
		-- creeps_Dire[i]:SetForceAttackTarget(hero)
	end

end

function CAddonTemplateGameMode:ForceKillCreep(creeps)
	-- print("kill creep")
	-- if #creeps > 0 then
	-- 	for i = 1, #creeps do
	-- 		if(creeps[i] ~= nil and creeps[i]:IsNull() == false and creeps[i]:IsAlive() )then
	-- 			creeps[i]:ForceKill(false)
	-- 		end
	-- 	end
	-- end
	allCreeps =  Entities:FindAllByName("npc_dota_creep_lane")
	for idx,creep in pairs( allCreeps ) do
		-- print(creep:GetName())
		if(creep ~= nil and creep:IsNull() == false and creep:IsAlive() )then
			creep:ForceKill(false)
		end
	end
	
end

function CAddonTemplateGameMode:getMinHpCreep(creeps)
	local creeps = creeps or creeps_Dire

	local minHp = 999;
	local minHp_creep = nil;

	for i, creep in pairs(creeps) do
		if(creep:IsNull() == false and creep:IsAlive() )then
			hp = creep:GetHealth();
			if( hp < minHp )then
				minHp = hp;
				minHp_creep = creep;
			end
		end
	end

	return minHp_creep, minHp

end

function CAddonTemplateGameMode:findDistanceMinCreep()

	local min_distance_creep, min_distance = self:getMinDistanceCreep(false)

	local minHp_creep, minHp = self.getMinHpCreep()

	if(min_distance == 1800)then -- no creeps
		return - 1.5, - 1.5;
	else
		local minHealthNormalize = normalize(minHp, 0, minHp_creep:GetMaxHealth())
		return minHealthNormalize, truePosition( minHp_creep ), truePosition(min_distance_creep)
	end

end

function CAddonTemplateGameMode:getMinDistanceCreep(bDistanceHero)
	local min_distance = 3000;
	local min_distance_creep = nil;

	for iEnemy, creepEnemy in pairs(creeps_Dire) do
		if(creepEnemy:IsNull() == false and creepEnemy:IsAlive() )then

			local distance = nil
			if(bDistanceHero)then
				distance = CalcDistanceBetweenEntityOBB( hero, creepEnemy)
			else
				distance = truePosition(creepEnemy)
			end

			if( distance < min_distance)then
				min_distance = distance;
				min_distance_creep = creepEnemy;
			end
		end

	end

	return min_distance_creep, min_distance
end

function CAddonTemplateGameMode:getCreepTarget(target, group_creep_attack)
	local result_group = {}
	local count = 1
	if target ~= nil then
		for key, creep in pairs(group_creep_attack) do
			if(creep:IsNull() == false and creep:IsAlive() )then
				if creep:GetAttackTarget() == target then
					result_group[count] = creep
					count = count + 1
				end
			end
		end
	end
	return result_group
end

--------- Support Function
function sleep(sec)
	target = GameRules:GetGameTime() + sec
	while GameRules:GetGameTime() < target do end
end

function normalize(value, min, max)
	return (value - min) / (max - min)
end

function truePosition(hUnit)
	distance = CalcDistanceBetweenEntityOBB( midRadianTower, hUnit)
	distance2 = CalcDistanceBetweenEntityOBB( mid3RadianTower, hUnit)
	-- print("distance "..distance.." max dis"..maxDistance)
	disNormalize = normalize(distance, 0, maxDistance)
	if(distance2 > distanceBetweenRadianTower)then -- outer tower
		return disNormalize
	else
		return - disNormalize -- inner tower
	end
end


----------
