

local Q_Model = require("q_learning")

num_state = 1
num_action = 3
env_low = { - 1}
env_high = {1}


local q_agent = Q_Model.new(num_state, num_action, env_low, env_high)
print( q_agent:act({1}) )
q_agent:updateQ_table({1}, {0.5}, 2, 1 )
q_agent:updateQ_table({1}, {0.5}, 2, 1 )
q_agent:updateQ_table({0.2}, {0.7}, 1, 5 )
q_agent:updateQ_table({ - 1}, {0.6}, 3, 5 )
printTable(q_agent.q_table, "q_table")
