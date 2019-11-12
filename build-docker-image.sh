#!/bin/bash

docker build \
    --target builder
    -t mpoell/rb-aosp:latest \
    --no-cache=true \
    .
