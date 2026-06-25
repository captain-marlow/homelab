Backups and snapshots are different.

Backups are separate from the virtual machine. It's a full clone of the disk. This backup can be moved to external media.

A snapshot is part of VM itself. You can't move it to another system. It's part of the VM disk, not a clone of the disk.

## Backups

Backups have more options than snapshots. You can choose where to store the backup. You *can* use local storage, but that defeats the purpose of backups.

There are different *modes* of backups; snapshot, suspend, and stop. These modes pertain to how much downtime you're willing to have. If you create a backup of a disk while a file is being written on that system, there's a possibility of corruption. *Suspend* is not recommended. The *Snapshot* mode for backups is not the same as ZFS snapshots. This mode has the least amount of downtime when it comes to backups. Proxmox uses backup processes for the snapshot mode of backups that does a live backup. The QEMU agent helps in this mode.

## Automated Backups
In the *Datacenter* view, you can create a task to automate backups for all VMs and containers. If you want to backup everything, make sure in *Selection mode* you select the option *All*. If you instead manually select which VMs and containers to backup, any new VMs or containers you add will not be automatically backed up.

## Snapshots
Snapshots are useful for testing. If you want to modify a VM, say by installing or removing an application, you can create a snapshot beforehand in case something goes wrong.

When you create a snapshot, you can also *Include RAM*. Although this it not necessary, it can be useful in some cases.

Once you have a snapshot, you can *Rollback* the snapshot when needed.