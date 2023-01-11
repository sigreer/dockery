#!/bin/bash
source .env*
_GREEN=$(tput setaf 2)
_BLUE=$(tput setaf 4)
_RED=$(tput setaf 1)
_RESET=$(tput sgr0)
_BOLD=$(tput bold)


function addbasicauth () {
        releaseinfo=$(lsb_release -a)
        htpasswdexists=$(command -v htpasswd)
        pwgenexists=$(command -v pwgen)
        if [[ ! $releaseinfo =~ "ebian" || ! $releaseinfo =~ "untu" ]] && [[ -z $htpasswdexists || -z $pwgenexists ]]; then
                echo "Please install pwgen and htpasswd (from apache2-utils) in order to generate passwords"
                echo "Exiting..."
                exit 0
        fi

        if [[ $releaseinfo =~ "ebian" || $releaseinfo =~ "untu" ]] && [[ -z $htpasswdexists && -z $pwgenexists ]]; then
                apt update && apt install apache2-utils pwgen -y -qq > /dev/null
        fi
        if [[ ! $releaseinfo =~ "ebian" || ! $releaseinfo =~ "untu" ]] && [[ -z $htpasswdexists && -z $pwgenexists ]]; then
                echo "Please install pwgen and htpasswd (from apache2-utils) in order to generate passwords"
                echo "Exiting..."
                exit 0
        fi
        basicauthname=$servicename-basicauth
        if [[ -z $useenvpass || $useenvpass == "0" ]]; then
        basicauthpassword=$(pwgen 12 1)
        fi
        basicauthpassword=$basicauthpass
        basicauthrawstring=$(echo $(htpasswd -nbB $basicauthuser $basicauthpassword))
        basicauthstring=$(echo $basicauthrawstring | sed -e s/\\$/\\$\\$/g)
    
cat <<EOF
      - traefik.http.middlewares.$basicauthname.users=$basicauthstring
      - traefik.http.routers.$servicename.middlewares=$basicauthname
EOF
}

function addnetwork () {
cat <<EOF
    networks:
      - ${traefiknetwork}
networks:
  ${traefiknetwork}:
    external: true
EOF
addnetwork=1
}

function generatelabels () {
cat <<EOF
    labels:
      - traefik.enable=true
      - traefik.http.routers.${servicename}.rule=Host(\`${appname}.${basedomain}\`)
      - traefik.http.routers.${servicename}.tls=true
      - traefik.http.routers.${servicename}.entrypoints=websecure
      - traefik.http.routers.${servicename}.tls.certresolver=${certresolver}
      - traefik.http.routers.${servicename}.service=${servicename}
      - traefik.http.services.${servicename}.loadbalancer.server.port=${containerport}
EOF
}

while [ ! -z "$1" ]; do 
case "$1" in
        +basicauth)
                addbasicauth=1
                shift;;
        +network)
                addnetwork=1
                shift;;
esac
done

generatelabels
if [[ $addbasicauth == 1 ]]; then
addbasicauth
fi
if [[ $addnetwork == 1 ]]; then
addnetwork
fi
if [[ $addbasicauth == 1 ]]; then
echo "" && echo ""
[[ $useenvpass == 0 || -z $useenvpass ]] && echo "Your Basic Auth Password is: ${_GREEN}${basicauthpassword}${_RESET}" || echo "Your Basic Auth password was set from your environment variables"
fi