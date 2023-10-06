#!/bin/bash

# Examples:
# $ ./docker make all
# $ ./docker.sh "echo | m68k-amigaos-gcc -dM -E -" | grep __VERSION__

# Use a published container
docker run --volume "$PWD":/host --workdir /host -i -t trixitron/m68k-amigaos-gcc /bin/bash -c "$*"
