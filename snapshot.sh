#!/bin/bash

sudo snapper -c root create --description "$1"
sudo snapper -c home create --description "$1"
sudo snapper -c log create --description "$1"
