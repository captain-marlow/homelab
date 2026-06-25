It will be useful to have a Samba network share so that different containers can read and write to one another. There are two generally recommended ways to do this
1. Use a prebuilt solution such as Webmin or cockpit in a LXC container. Just bind mount any directory you wish to share and then create network share in the container. 
2. Manually install and setup Samba sharing. Only use one LXC and simply add any bind mount you wish to share over the network to that single LXC. 

https://www.youtube.com/watch?v=qmSizZUbCOA