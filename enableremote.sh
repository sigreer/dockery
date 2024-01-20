#!/bin/bash
## Simon Greer 01/2024
## https://github.com/sigreer

## ENABLE DOCKER HOST FOR REMOTE MANAGEMENT
## This script accepts a docker hostname as an argument, tests to see if the management port is open
## If not, it connects to the remote host, modifies the config, restarts the daemon and restests before returning

hostarg=$1
sshhostip=$(ssh -G "$hostarg" | awk '$1 == "hostname" { print $2 }')
dockermanport=2375
manportopen=""
thishost=""

checkArgs() {
    ## Check if an argument is supplied
    if [[ -z $hostarg ]]; then
        echo "Please supply a user@host or SSH host reference to connect to"
        exit 1
    fi
    ## If the argument contains no '@', assign it as an SSH reference extract the IP as part of the variable assignment
    if [[ ! $hostarg =~ "@" ]]; then
        thishost=$sshhostip
    else
    ## If the argument contains '@', extract the hostname part of the argument
        thishost=${hostarg#*@}
    fi
}

testPort() {
    ## Probe the host to using netcat to see if the Docker management port is open
    { bash -c "cat </dev/null > /dev/tcp/${thishost}/${dockermanport}"; } 2>/dev/null
    manportopen=$?
    ## If it's closed, continue, if it's open, exit the script
    if [[ $manportopen -eq 0 ]]; then
        echo "Port open on $thishost. No further action required."
        echo "Exiting..."
        exit 0
    else
        echo "Port is closed. Connecting to host to modify service"
    fi
}

## Write config to docker deamon file
command1='sudo sh -c '\''echo "{\"hosts\": [\"tcp://0.0.0.0:2375\", \"unix:///var/run/docker.sock\"]}" > /etc/docker/daemon.json'\'
command2='sudo mkdir -p /etc/systemd/system/docker.service.d'
command3='sudo sh -c '\''echo "[Service]" > /etc/systemd/system/docker.service.d/override.conf'\'
command4='sudo sh -c '\''echo "ExecStart=" >> /etc/systemd/system/docker.service.d/override.conf'\'
command5='sudo sh -c '\''echo "ExecStart=/usr/bin/dockerd" >> /etc/systemd/system/docker.service.d/override.conf'\'
command6='sudo systemctl daemon-reload'
command7='sudo systemctl restart docker'

executeRemote() {
    ssh "$hostarg" "${command1} && ${command2} && ${command3} && ${command4} && ${command5} && ${command6} && ${command7}" && echo "Completed commands!"
}

checkArgs
testPort
executeRemote
testPort

