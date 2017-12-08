# CSV
import csv
import logging
import pickle
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path

import numpy as np

import control_server as cs
from dqn_append import DQN
from flask import Flask, jsonify, redirect, request, url_for
from keras.models import load_model

import logging
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)




app = Flask(__name__)

num_input = 3
num_output = 4
list_hidden = [20, 20, 20]

num_input_append = 1
num_output_append = 1

pathSaveFile = "obj_dqn/dqn_lasthit_03.model"
pathAppend = "obj_dqn/dqn_03.model"

dqn_save = None
checkFirst = True


def getModel(pathAppend=None):
    my_file = Path(pathSaveFile)
    if my_file.is_file():
        print("load")
        return DQN(path=pathSaveFile)
    else:
        if pathAppend == None:
            print("create new")
            return DQN(num_input=num_input, num_output=num_output, list_hidden=list_hidden)
        else:
            print("create append")
            return DQN(path_append=pathAppend, num_input=num_input_append, num_output=num_output_append)


dqn_agent = None


@app.route('/', methods=['POST', 'GET'])
def getValue():
    data = request.json

    global dqn_save, checkFirst

    if checkFirst:
        dqn_agent = getModel()
        checkFirst = False
    else:
        dqn_agent = dqn_save

    dqn_save = dqn_agent
    return cs.runControl(dqn_agent, data, pathSaveFile)


if __name__ == '__main__':
    print("ready")
    app.run(host='0.0.0.0', port=8080, debug=True)
