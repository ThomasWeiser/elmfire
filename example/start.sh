#!/usr/bin/env bash

set -e

elm make src/Example.elm --output Example.js

open index.html
