#!/bin/bash

docker build \
    --target builder \
    --tag "mpoell/rb-aosp:latest" \
    --no-cache=true \
    .
