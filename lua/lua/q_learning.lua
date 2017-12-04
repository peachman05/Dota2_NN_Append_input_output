local Q_Model = {} -- the table representing the class, which will double as the metatable for the instances
Q_Model.__index = Q_Model -- failed table lookups on the instances should fallback to the class table, to get methods

-- syntax equivalent to "MyClass.new = function..."
function Q_Model.new(num_state, num_action, env_low, env_high, divide_state)
  local self = setmetatable({}, Q_Model)

  self.gamma = 0.99
  self.epsilon = 0.01
  self.learning_rate = 0.005
  self.n_states = divide_state
  self.num_state = num_state
  self.num_action = num_action
  self.env_low = env_low
  self.env_high = env_high
  self.env_dx = self:calculate_env_dx()
  self.q_table = {}

  -- printTable(self.env_dx,"env_dx")

  return self
end

function Q_Model.calculate_env_dx(self)
  temp_dx = {}

  for i = 1, self.num_state do
    temp_dx[i] = (self.env_high[i] - self.env_low[i]) / self.n_states[i]
  end
  return temp_dx
end

-------- necessary function
function Q_Model.act(self, obs)
  local stateMap = self:obs_to_state(obs)

  if( RandomFloat(0, 1) < self.epsilon )then
    print("random")
    return RandomInt(1, self.num_action)
    -- if( 0.5 < self.epsilon )then
    -- 	return 5
  else
    -- local probs = {}
    -- self:softmax(self.q_table[stateMap],probs) -- pass by reference
    -- action = self:randomChoice(probs)
    action, _ = self:findMax(self.q_table[stateMap])

    local probs2 = self.q_table[stateMap]
    print(stateMap)
    -- self:printTable(obs, "---obs---")
    return action, probs2
  end

end

------return key string
function Q_Model.obs_to_state(self, obs)
  local state = {}

  for i = 1, self.num_state do
    state[i] = math.floor((obs[i] - self.env_low[i]) / self.env_dx[i])
  end

  local state_string = table.tostring(state)
  if(self.q_table[state_string] == nil)then
    local zero_list = {}
    for i = 1, self.num_action do
      zero_list[i] = 0
    end
    self.q_table[state_string] = zero_list
  end

  -- if(state_string == "{-17}")then
  -- 	print(obs[i])
  -- end
  -- print("state :"..state_string)
  return state_string
end

function Q_Model.updateQ_table(self, obs, new_obs, action, reward)
  local state = self:obs_to_state(obs)
  local new_state = self:obs_to_state(new_obs)
  _, maxAction = self:findMax(self.q_table[new_state])

  -- printTable(self.q_table,"q_table")
  -- print(state)
  -- print(new_state)
  -- print("state = "..state)
  -- print("new_state = "..new_state)
  -- self:printTable(self.q_table[state],"--value--")

  temp = reward + self.gamma * maxAction - self.q_table[state][action]
  self.q_table[state][action] = self.q_table[state][action] + self.learning_rate * temp

  -- print("delta = "..temp)
end

------ support function

function Q_Model.findMax(self, table)
  key, max = 1, table[1]
  -- print(key.." "..1)
  for k, v in ipairs(table) do
    if table[k] > max then
      key, max = k, v
    end
  end

  return key, max
end

function Q_Model.softmax(self, actionTable, probs)
  temp = actionTable

  logits_exp = {}
  for i, v in pairs(temp) do
    logits_exp[i] = math.exp(temp[i])
  end
  sum = 0
  for i, v in pairs(logits_exp) do
    sum = sum + v
  end

  for i, v in pairs(logits_exp) do
    probs[i] = v / sum
  end
  -- printTable(probs,"probs")
end

function Q_Model.randomChoice(self, probs_table)

  randomNumber = RandomFloat(0, 1)
  sum = 0
  for i, v in pairs(probs_table) do
    sum = sum + v
    if(randomNumber <= sum)then
      return i
    end
  end
end

function Q_Model.printTable(self, table, name)
  print("-----"..name.."------")
    for i, v in pairs(table) do

      if(type(i) ~= "table" )then
        print("key: "..i)
      else
        for i2, v2 in pairs(i) do
          print("key: "..i2.." value: "..v2)
        end
      end

      if(type(v) ~= "table" )then
        print("     value: "..v)
      else
        for i2, v2 in pairs(v) do
          print("     key: "..i2.." value: "..v2)
        end
      end
    end
  end

  function Q_Model.shallowcopy(self, orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
      copy = {}
      for orig_key, orig_value in pairs(orig) do
        copy[orig_key] = orig_value
      end
    else -- number, string, boolean, etc
      copy = orig
    end
    return copy
  end

  function table.val_to_str ( v )
    if "string" == type( v ) then
      v = string.gsub( v, "\n", "\\n" )
      if string.match( string.gsub(v, "[^'\"]",""), '^" + $' ) then
        return "'" .. v .. "'"
      end
      return '"' .. string.gsub(v, '"', '\\"' ) .. '"'
    else
      return "table" == type( v ) and table.tostring( v ) or
      tostring( v )
    end
  end

  function table.key_to_str ( k )
    if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
      return k
    else
      return "[" .. table.val_to_str( k ) .. "]"
    end
  end

  function table.tostring( tbl )
    local result, done = {}, {}
    for k, v in ipairs( tbl ) do
      table.insert( result, table.val_to_str( v ) )
      done[ k ] = true
    end
    for k, v in pairs( tbl ) do
      if not done[ k ] then
        table.insert( result,
        table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
      end
    end
  return "{" .. table.concat( result, "," ) .. "}"
end
-- function getStringFromList(list)
-- 	table.concat(list, ",")
-- end


return Q_Model

-- num_state = 1
-- num_action = 3
-- env_low = {-1}
-- env_high = {1}


-- local q_agent = Q_Model.new(num_state,num_action,env_low,env_high)
-- print( q_agent:act({1}) )
-- q_agent:updateQ_table({1}, {0.5}, 2, 1 )
-- q_agent:updateQ_table({1}, {0.5}, 2, 1 )
-- q_agent:updateQ_table({0.2}, {0.7}, 1, 5 )
-- q_agent:updateQ_table({-1}, {0.6}, 3, 5 )
-- printTable(q_agent.q_table,"q_table")
