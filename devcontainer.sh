#!/bin/bash

if ! [ -x "$(command -v jq)" ]; then
    printf "\x1B[31m[ERROR] jq is not installed.\x1B[0m\n"
    exit 1
fi
OPTIND=1
VERBOSE=0

while getopts "v" opt; do
    case ${opt} in
        v ) VERBOSE=1 ;;
    esac
done

debug() {
    if [ $VERBOSE == 1 ]; then
        printf "\x1B[33m[DEBUG] ${1}\x1B[0m\n"
    fi
}

WORKSPACE=${1:-`pwd`}
CURRENT_DIR=${PWD##*/}
echo "Using workspace ${WORKSPACE}"

CONFIG_DIR=./.devcontainer
debug "CONFIG_DIR: ${CONFIG_DIR}"
CONFIG_FILE=devcontainer.json
debug "CONFIG_FILE: ${CONFIG_FILE}"
if ! [ -e "$CONFIG_DIR/$CONFIG_FILE" ]; then
    echo "Folder contains no devcontainer configuration"
    exit
fi

CONFIG=$(cat $CONFIG_DIR/$CONFIG_FILE | grep -v //)
debug "CONFIG: \n${CONFIG}"

cd $CONFIG_DIR

DOCKER_FILE=$(echo $CONFIG | jq -r .dockerFile)
if [ "$DOCKER_FILE" == "null" ]; then 
    DOCKER_FILE=$(echo $CONFIG | jq -r .build.dockerfile)
fi
DOCKER_FILE=$(readlink -f $DOCKER_FILE)
debug "DOCKER_FILE: ${DOCKER_FILE}"
if ! [ -e $DOCKER_FILE ]; then
    echo "Can not find dockerfile ${DOCKER_FILE}"
    exit
fi

REMOTE_USER=$(echo $CONFIG | jq -r .remoteUser)
debug "REMOTE_USER: ${REMOTE_USER}"
if ! [ "$REMOTE_USER" == "null" ]; then
    REMOTE_USER="-u ${REMOTE_USER}"
fi

BUILD_ARGS=$(echo $CONFIG | jq -r '.build.args | to_entries? | map("--build-arg \(.key)=\"\(.value)\"")? | join(" ")')
debug "BUILD_ARGS: ${BUILD_ARGS}"

RUN_ARGS=$(echo $CONFIG | jq -r '.runArgs? | join(" ")')
debug "RUN_ARGS: ${RUN_ARGS}"

SHELL=$(echo $CONFIG | jq -r '.settings."terminal.integrated.shell.linux"')
debug "SHELL: ${SHELL}"

PORTS=$(echo $CONFIG | jq -r '.forwardPorts | map("-p \(.):\(.)")? | join(" ")')
debug "PORTS: ${PORTS}"

ENVS=$(echo $CONFIG | jq -r '.remoteEnv | to_entries? | map("-e \(.key)=\(.value)")? | join(" ")')
debug "ENVS: ${ENVS}"

WORK_DIR="/workspace"
debug "WORK_DIR: ${WORK_DIR}"

MOUNT="${MOUNT} --mount type=bind,source=${WORKSPACE},target=${WORK_DIR}"
debug "MOUNT: ${MOUNT}"

DOCKER_IMAGE_HASH=$(docker build -f $DOCKER_FILE $ARGS . | awk '/Successfully built/ {print $NF}')
debug "DOCKER_IMAGE_HASH: ${DOCKER_IMAGE_HASH}"

NAME=$(echo $CONFIG | jq -r '.name')
debug "NAME: ${NAME}"
echo "Container name: \"$NAME\""

docker run --name $NAME -it $RUN_ARGS $PORTS $MOUNT -w $WORK_DIR $DOCKER_IMAGE_HASH $SHELL
