#!/bin/sh

# Certain commands cannot be run in Dockerfile including pbuilder run them here
sudo pbuilder create --distribution unstable
