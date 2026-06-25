https://www.youtube.com/watch?v=MJgIm03Jxdo&list=PLT98CRl2KxKHnlbYhtABg6cF50bYa8Ulo&index=21

Create a new VM and give it no ISO image (*Do not use any media)*, and also give it no disk. After VM is created, go to *Hardware* and add a new CloudInit drive. 

Go to CloudInit drive and set default values (username, password, SSH key, and DHCP IP address). A cloud image is an already installed OS, so it won't ask you questions during install as there is no install. 

Remember to install QEMU agent: `sudo apt install qemu-guest-agent`

After installing agent, reboot system to enable. Check status `systemctl status qemu-quest-agent`