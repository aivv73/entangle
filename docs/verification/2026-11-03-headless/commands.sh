#!/bin/sh
set -eu
bend version
clang --version
clang -dumpmachine
git submodule status --recursive
bend PROOF.bend
bend examples/scene.bend -o /tmp/entangle-headless-scene.c
clang -std=c11 -O2 /tmp/entangle-headless-scene.c -lpthread -lm -ldl -o /tmp/entangle-headless-scene
env -u DISPLAY -u WAYLAND_DISPLAY /tmp/entangle-headless-scene --threads 1 --gpu off
bend tools/verify.bend
