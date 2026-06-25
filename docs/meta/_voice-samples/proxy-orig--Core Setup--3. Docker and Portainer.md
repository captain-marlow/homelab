## Install Docker
To install docker on the system:
```bash
apt install docker.io
systemctl enable docker
systemctl start docker
systemctl status docker
```

#### Setup docker user and group
It's important that Docker run using the sudo user created 

OLD: Right now the only way we can run Docker commands is through our `root` user. Docker automatically created a group called `docker` which any user can be added to in order to run Docker commands. Let’s create a new user named `docker` and add them to the `docker` group.
```
useradd -m -s /bin/bash docker -g docker
```
If you created a user and group in an unprivileged LXC, add user to docker group: `sudo usermod -aG docker [user-name]`

### Portainer
Portainer is a tool for managing and deploying docker containers. 

First, create a docker volume for Portainer: 
`docker volume create portainer_data`

Install Portainer with:
```
docker run -d \
--name="portainer" \
--restart on-failure \
-p 9000:9000 \
-v /var/run/docker.sock:/var/run/docker.sock \
-v portainer_data:/data \
portainer/portainer-ce
```

The container will run on the port specified and given an IP by the DCHP provider. You can check Portainer's IP with `ip addr`. 

#### Create Container from Image Using Portainer
Some good resources for containers is linuxserver.io.

Copy the `docker run` command with all its options using the Portainer UI. 

Map to the correct volume: 
```
container: /config
host: /mnt/[share-name]/docker/[container-name]
```


### SSL Certs and Domain for LXC containers
https://www.youtube.com/watch?v=qlcVx-k-02E

Use that package called geuloen or whatever instead?