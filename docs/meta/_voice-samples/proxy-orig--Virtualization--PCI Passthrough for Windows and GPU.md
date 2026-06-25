
https://dazeb.uk/proxmox-vm-gpu-hardware-acceleration-for-jellyfin-plex-emby/

[https://www.reddit.com/r/homelab/comments/b5xpua/the\_ultimate\_beginners\_guide\_to\_gpu\_passthrough/](https://www.reddit.com/r/homelab/comments/b5xpua/the_ultimate_beginners_guide_to_gpu_passthrough/)

https://www.youtube.com/watch?v=S6jQx4AJlFw&pp=ygUicHJveG1veCB3aW5kb3dzIDExIGdwdSBwYXNzdGhyb3VnaA%3D%3D

This guy said he followed Reddit's Ultimate Guide and added some additional commands to grub that allowed for multi-passthrough:

> I followed this guide to the T. However, there was something missing. I thought that I needed to get the rom files for my GPUs, both NVIDIA an HP 3060 and an EVGA 3070. However, I was wrong. It didn't help any. However, in many different ways this method "added" to this guide HELPED alot. I can do multi-passthrough. It feels good. Here is the addition that truly made it work 100%
> 
> \[GRUB\_CMDLINE\_LINUX\_DEFAULT="quiet intel\_iommu=on pcie\_acs\_override=downstream,multifunction video=efifb:off video=vesa:off vfio-pci.ids=10de:13bb,10de:0fb vfio\_iommu\_type1.allow\_unsafe\_interrupts=1 kvm.ignore_msrs=1 modprobe.blacklist=radeon,nouveau,nvidia,nvidiafb,nvidia-gpu"\]

# PCI Passthrough - Quick Guide

List all devices, find the device you wish to passthrough, and select its bus and device number:

`lspci -v`

Each device will be identified by a number such as 01:00.0 (bus number 01, device number 00, function 0). You want the bus number and the device number i.e. 01:00

Now retrieve the vendor IDs for the device:

`lspci -n -s 01:00`

The output will look like `12:00.0 0280: 8086:2725 (rev 1a)`. We're interested in the vendor ID `8086:2725`. Select all vendor IDs if more than one is listed.

Now add the device's vendor IDs to VFIO:

`echo "options vfio-pci ids=10de:1b81,10de:10f0 disable_vga=1"> /etc/modprobe.d/vfio.conf`

Now update and reset:

`update-initramfs -u`

`reset`

Now the device should be ready to be passed through to a VM. Go to a VM, select the hardware tab, and add your PCI device. Check the boxes labelled "All Functions", "ROM-bar", and (if applicable) "PCI-Express".