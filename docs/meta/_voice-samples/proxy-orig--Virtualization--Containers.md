Proxmox uses LXC (pronounced luk-see) containers. LXC uses templates. You need one to get started. Proxmox has some built in. You can add templates in *local*. 

The setup is similar to a VM.

## Container Options

The options for containers are similar to VMs. One different option is *Unprivileged container*. An unprivileged container will map the root user differently for security. If an application isn't working in a container, it's often the case that the application needs privileges. By default you should use *unprivileged *containers.