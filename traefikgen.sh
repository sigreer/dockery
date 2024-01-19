#!/bin/bash
## Simon Greer 01/2024
## https://github.com/sigreer

## Generate Traefik Docker labels quickly and easily

# shellcheck source="./.env"
source .env*
_GREEN=$(tput setaf 2)
_BLUE=$(tput setaf 4)
_RED=$(tput setaf 1)
_RESET=$(tput sgr0)
_BOLD=$(tput bold)

function parseComposeFile() {
    dirName=""
    function extractLastDir() {
        local fullPath=$1
        
        # If the path ends with a '/', remove it
        fullPath=${fullPath%/}

        # Check if the path contains a filename
        if [[ -f $fullPath ]]; then
            # Extract the directory part and then the last directory name
            dirName=$(basename "$(dirname "$fullPath")")
        else
            # Extract the last directory name
            dirName=$(basename "$fullPath")
        fi

        # Remove special characters
        dirName=$(echo "$dirName" | tr -cd '[:alnum:]_')

        echo "$dirName"
    }

    if [[ $composefile =~ "/" ]]; then
        app_prefix=$(extractLastDir "$composefile")
        echo "app_prefix=${app_prefix}"
    fi


    ## Check to see if YQ is installed and v4+
    yq_version=$(yq --version 2>&1 | grep -oP '.*v\K(\d[\d\.]+)')
    if [[ ! $yq_version =~ ^4\. ]]; then
        echo "yq version 4 or greater is required to parse docker-compose.yml files. Please install or omit the -file argument."
        exit 1
    fi    
    local composeFile=$composefile
    echo "$composeFile"
    local services=($(yq e '.services | keys | .[]' "$composeFile"))
    local index=1

    echo "Available services:"
    for service in "${services[@]}"; do
        echo "$index) $service"
        index=$((index+1))
    done

    read -p "Choose a service by number: " selectedIndex
    servicename=$(echo "$app_prefix-${services[selectedIndex-1]}")

    if [ -z "$servicename" ]; then
        echo "Invalid selection."
        return 1
    fi

    echo "Selected service: $servicename"
}

function addBasicAuth () {
    releaseinfo=$(lsb_release -a)
    htpasswdexists=$(command -v htpasswd)
    pwgenexists=$(command -v pwgen)
    if [[ ! $releaseinfo =~ "ebian" || ! $releaseinfo =~ "untu" ]] && [[ -z $htpasswdexists || -z $pwgenexists ]]; then
        echo "Please install pwgen and htpasswd (from apache2-utils) in order to generate passwords"
        echo "Exiting..."
        exit 1
    fi

    if [[ $releaseinfo =~ "ebian" || $releaseinfo =~ "untu" ]] && [[ -z $htpasswdexists && -z $pwgenexists ]]; then
        apt update && apt install apache2-utils pwgen -y -qq > /dev/null
    fi
    if [[ ! $releaseinfo =~ "ebian" || ! $releaseinfo =~ "untu" ]] && [[ -z $htpasswdexists && -z $pwgenexists ]]; then
        echo "Please install pwgen and htpasswd (from apache2-utils) in order to generate passwords"
        echo "Exiting..."
        exit 0
    fi
    basicauthname="${servicename}-basicauth"
    if [[ -z $useenvpass || $useenvpass == "0" ]]; then
        basicauthpassword=$(pwgen 12 1)
    fi
    basicauthpassword=$basicauthpass
    basicauthrawstring=$(echo $(htpasswd -nbB $basicauthuser $basicauthpassword))
    basicauthstring=$(echo "${basicauthrawstring}" | sed -e s/\\$/\\$\\$/g)
    
cat <<EOF
      - traefik.http.middlewares.$basicauthname.users=$basicauthstring
      - traefik.http.routers.$servicename.middlewares=$basicauthname
EOF
}

function addNetwork () {
cat <<EOF
    networks:
      - ${traefiknetwork}
networks:
  ${traefiknetwork}:
    external: true
EOF
addnetwork=1
}

function generateLabels () {
cat <<EOF
    labels:
      - traefik.enable=true
      - traefik.http.routers.${servicename}.rule=Host(\`${appname}.${basedomain}\`)
      - traefik.http.routers.${servicename}.tls=true
      - traefik.http.routers.${servicename}.entrypoints=websecure
      - traefik.http.routers.${servicename}.tls.certresolver=${certresolver}
      - traefik.http.routers.${servicename}.service=${servicename}
      - traefik.http.services.${servicename}.loadbalancer.server.port=${containerport}
      - traefik.docker.network=${traefiknetwork}
EOF
}

while [  -n "$1" ]; do 
case "$1" in
        +basicauth)
                addbasicauth=1
                shift;;
        +network)
                addnetwork=1
                shift;;
        -file)
                fromfile=1
                composefile="$2"
                shift
                shift;;
esac
done

## If a file is specified, parse it for the relevant config info
if [[ $fromfile == 1 ]]; then
    parseComposeFile
fi

## Generate the base set of Traefik labels
generateLabels

## If basic auth is specified as an argument, append relevant config
if [[ $addbasicauth == 1 ]]; then
    addBasicAuth
fi

## If network is specified as an argument, append relevant config
if [[ $addnetwork == 1 ]]; then
    addNetwork
fi

## If basic auth specified, provide details of password.
if [[ $addbasicauth == 1 ]]; then
    echo ""
    [[ $useenvpass == 0 || -z $useenvpass ]] && echo "${_BLUE} Your Basic Auth Password is: ${_GREEN}${basicauthpassword}${_RESET}" || echo "${_BLUE} Your Basic Auth password was set from your environment variables ${_RESET}"
fi