import random
from collections import deque
from pathlib import Path

import numpy as np

from keras.layers import Dense, Dropout
from keras.models import Sequential, load_model
from keras.optimizers import Adam


class DQN:
    def __init__(self, num_input=None, num_output=None, list_hidden=None, path=None, path_append=None):

        self.learning_rate = 0.001
        self.num_input = None
        self.num_output = None

        if path == None:  # create
            if path_append == None:  # create -> new
                print("create -> new")
                model = self.create_model(num_input, num_output, list_hidden)
                target_model = self.create_model(
                    num_input, num_output, list_hidden)
            else:  # create -> append
                model = self.append_model(num_input, num_output, path_append)
                target_model = self.append_model(
                    num_input, num_output, path_append)
        else:  # load old model
            model_num_input, model_num_output, model = self.load_old_model(
                path)
            _, _, target_model = self.load_old_model(path)
            self.num_input = model_num_input
            self.num_output = model_num_output

        self.model = model
        self.target_model = target_model

        self.list_hidden = self.get_hidden_layer()

        self.memory = deque(maxlen=5000)
        self.gamma = 0.99

    def append_model(self, num_append_input, num_append_output, path_append):
        _, _, old_model = self.load_old_model(path_append)
        print(old_model)
        new_model = Sequential()
        print("---")
        for indx, layer in enumerate(old_model.layers):
            old_weight = layer.get_weights()
            # print(old_weight)
        print("---")

        for indx, layer in enumerate(old_model.layers):
            old_weight = layer.get_weights()
            size_node = len(old_weight[0][0])
            # print("old weight")
            # print(old_weight)
            if indx == 0:
                # print("len="+str(len(old_weight))+" "+str(num_append_input))
                new_input = len(old_weight[0]) + num_append_input
                new_model.add(
                    Dense(size_node, input_dim=new_input, activation="relu"))
                # print("before ")
                # print( new_model.layers[0].get_weights() )
                new_weight = old_weight

                for i in range(num_append_input):  # create zero weight

                    new_weight[0] = np.append(new_weight[0], np.zeros(
                        size_node).reshape(1, size_node), axis=0)

                # print("new weight")
                # print(new_weight)
                new_model.layers[0].set_weights(new_weight)
                self.num_input = new_input

            elif indx == len(old_model.layers) - 1:
                new_weight = []
                new_weight = old_weight
                for i in range(num_append_output):
                    new_weight[0] = np.insert(
                        new_weight[0], size_node, 0, axis=1)
                    new_weight[1] = np.append(new_weight[1], [0])

                # new_weight.append( temp )
                # new_weight.append( )
                new_model.add(Dense(size_node + num_append_output))
                # print( new_model.layers[-1].get_weights())
                # print(new_weight)
                new_model.layers[-1].set_weights(new_weight)
                self.num_output = size_node + num_append_output

            else:
                new_model.add(Dense(size_node, activation="relu"))
                # print("before ")
                # print( new_model.layers[-1].get_weights() )

                # print("new ")
                # print( old_weight )

                new_model.layers[-1].set_weights(old_weight)

        new_model.compile(loss="mean_squared_error",
                          optimizer=Adam(lr=self.learning_rate))
        return new_model

    def create_model(self, num_input, num_output, list_hidden):

        self.num_input = num_input
        self.num_output = num_output

        model = Sequential()
        model.add(
            Dense(list_hidden[0], input_dim=num_input, activation="relu"))
        for num_node in list_hidden[1:]:
            print(num_node)
            model.add(Dense(num_node, activation="relu"))
        model.add(Dense(num_output))
        model.compile(loss="mean_squared_error",
                      optimizer=Adam(lr=self.learning_rate))

        return model

    def update_mem(self, data):
        print("update mem")
        self.memory.extend(data)

    def replay(self):
        # batch_size = 500
        # if len(self.memory) < batch_size:
        #     print("return")
        #     return

        # samples = random.sample(self.memory, batch_size)
        list_state = []
        list_target = []

        samples = random.sample(self.memory, len(self.memory))
        print("replay")
        for indx, sample in enumerate(samples):
            # for sample in samples:
            state, new_state, action, reward = sample

            state = np.asarray(state).reshape(1, self.num_input)
            new_state = np.asarray(new_state).reshape(1, self.num_input)

            target = self.target_model.predict(state)

            Q_future = max(self.target_model.predict(new_state)[0])
            target[0][action - 1] = reward + Q_future * self.gamma

            list_state.append(state[0].tolist() )
            list_target.append(target[0].tolist() )

            # self.model.fit(state, target, epochs=1, verbose=0)
            # print("round "+str(indx))

            # print(str(target[0][action]))
            
        print(self.model.fit(list_state, list_target, nb_epoch=10,batch_size=32, verbose=0 ).history)
        print("----------")
        self.memory.clear()

    def get_hidden_layer(self):

        hidden_list = []
        for layer in self.model.layers[1:]:
            hidden_list.append(len(layer.get_weights()[0]))

        return hidden_list

    def target_update(self):
        weights = list(self.model.get_weights())
        # target_weights = self.target_model.get_weights()
        self.target_model.set_weights(weights)
        print("finish target update")

    def save_model(self, path):
        self.model.save(path)

    def load_old_model(self, path):
        my_file = Path(path)
        if my_file.is_file():
            print("load")
            model_load = load_model(path)
            num_input = len(model_load.layers[0].get_weights()[0])
            num_output = len(model_load.layers[-1].get_weights()[0][0])
            return num_input, num_output, model_load
        else:
            print("file not found")

# path = "obj_dqn/"

# agent = DQN(num_input=2, num_output=1, list_hidden=[2,3])

# agent = DQN(path=path+"success.model")

# agent = DQN(path_append=path+"success3.model", num_input=2, num_output=3)

# print("++++++")
# for indx,layer in enumerate(agent.model.layers):
    # print(layer.get_weights())

# agent.save_model(path+"success4.model")
