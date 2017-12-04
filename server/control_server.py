from flask import jsonify

GET_MODEL_STATE = 20
UPPDATE_MODEL_STATE = 21
GET_DQN_DETAIL = 22
GET_WEIGHT = 23
GET_BIAS = 24


def get_weight_bias(dqn_agent_temp):
    dict_send = {}
    dict_send['weights_all'] = []
    # dict_send['bias_all'] = []
    for layer in dqn_agent_temp.model.layers:
        dict_send['weights_all'].append(layer.get_weights()[0].tolist())
        # dict_send['bias_all'].append(  layer.get_weights()[1].tolist()  )
    return jsonify(dict_send)


global dqn_save, checkFirst


def runControl(dqn_agent, data, pathSaveFile):

    if data['method'] == GET_DQN_DETAIL:
        print("get model")

        detail_dict = {}
        detail_dict['num_input'] = dqn_agent.num_input
        detail_dict['num_output'] = dqn_agent.num_output
        detail_dict['list_hidden'] = dqn_agent.list_hidden
        return_thing = jsonify(detail_dict)

    elif data['method'] == GET_WEIGHT:
        layer = data['layer']
        row = data['row']
        print(str(layer) + " " + str(row))
        print(dqn_agent)
        # use lua indexing (start with 1 )
        weight_layer = dqn_agent.model.layers[layer - 1].get_weights()
        weight_dict = {}
        weight_dict['weight'] = weight_layer[0][row - 1].tolist()
        return_thing = jsonify(weight_dict)

    elif data['method'] == GET_BIAS:
        # use lua indexing (start with 1 )
        weight_layer = dqn_agent.model.layers[data['layer'] - 1].get_weights()
        weight_dict = {}
        weight_dict['bias'] = weight_layer[1].tolist()

        return_thing = jsonify(weight_dict)

    elif data['method'] == UPPDATE_MODEL_STATE:
        # print(data)
        print("len :" + str(len(data['mem_episode'])))
        # for each in data['mem_episode']:
        #   print(each)

        dqn_agent.update_mem(data['mem_episode'])
        dqn_agent.replay()
        dqn_agent.target_update()
        print("finish")
        dqn_agent.save_model(pathSaveFile)

        return_thing = "1"
        # return get_weight_bias()
    else:
        print("dddd method" + str(data['method']))

    return return_thing
