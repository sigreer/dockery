# dockery

**Scripts to make it easier to manage Docker-based environments**

This script collection is designed to be run on a local workstation. Where remote actions are performed, they are done so using SSH.

## enableremote.sh
To remotely monitor and manage Docker hosts (using something like UptimeKuma, for instance), you need to expose the daemon on its TCP management port (2375). This script accepts a single argument which can be either an SSH 'Host' reference from a local config file, ``myserver`` for example; or a standard username and hostname string , eg. ``user@10.0.0.10``. It will then check to see if the port is already accessible using NetCat. If so, it will exit cleanly.

If the port is not open, it will connect to the remote host and execute a series of commands that:
1. Add a JSON config file to the Docker config directory on the specified host
2. Create a systemd override.conf file to allow for docker daemon clean reloading using systemd
3. Reloads the deamon config set
4. Restarts docker service using systemd
5. Rechecks the port on the remote host and confirms that the port has been activated

**This script relies on the remote using being able to execute commands using sudo without a password prompt to run efficiently**

## traefikgen.sh
Generates Traefik labels either from arguments, a docker-compose.yml file or a .env file.

Usage:
```
./terraefik.sh +basicauth +network -file "exampledata/docker-compose.yml"

Using docker-compose.yml directory as app's prefix app_prefix. Found 'exampledata'

Which service in the docker-compose.yml file do you want to generate traefik labels for?

Available services:
1) app
2) postgres

Choose a service by number: 1

Selected service: exampledata-app

Here is your config:

    labels:
      - traefik.enable=true
      - traefik.http.routers.exampledata-app.rule=Host(`dozzle.bayou.tech`)
      - traefik.http.routers.exampledata-app.tls=true
      - traefik.http.routers.exampledata-app.entrypoints=websecure
      - traefik.http.routers.exampledata-app.tls.certresolver=cloudflare
      - traefik.http.routers.exampledata-app.service=exampledata-app
      - traefik.http.services.exampledata-app.loadbalancer.server.port=8080
      - traefik.docker.network=traefik
      - traefik.http.middlewares.exampledata-app-basicauth.users=simon:$$2y$$05$$GQhgac0ZeZwn3bkKoOE.IOKOrsxFBQ1JpHC.RDP/1ss3199OCi21i
      - traefik.http.routers.exampledata-app.middlewares=exampledata-app-basicauth
    networks:
      - traefik
networks:
  traefik:
    external: true
```

## list.py

Connects to an array of Docker hosts as specified in your .env file and lists the services, where they're located and their parent directory. This parses file information only, and is a quick way of checking which server a particular app is located on, whether or not it is running.

Example output:
```
python list.py

+-------------+--------------------------+--------------------+
|     Host    |           App            |      Category      |
+-------------+--------------------------+--------------------+
| docker1.dc1 |        watchtower        |     production     |
| docker1.dc1 |          dozzle          |     production     |
| docker1.dc1 |       uptimetatems       |     production     |
| docker1.dc1 |           elk            |      archive       |
| docker1.dc1 |        authentik         |      archive       |
| docker1.dc1 |        bookstack         |      archive       |
| docker2.dc1 |          titra           |    development     |
| docker2.dc1 |          homer           |    development     |
| docker4.dc1 |          saleor          |     production     |
| docker4.dc1 |         docuseal         |     production     |
|   web3.dc1  |      sandhistaging       |     development    |
|   web3.dc1  |      connectyoulive      |     production     |
+-------------+--------------------------+--------------------+
```

Prereqs:
```
pip install -r requirements.txt
```
