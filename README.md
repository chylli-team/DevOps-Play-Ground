# DevOps-Play-Ground

it is a script that create a cluster on virtualbox on windows.

# Preparing

1. in virtualbox create a new host-only network with the name "VirtualBox Host-Only Ethernet Adapter" and ip 192.168.56.1 and mask. Of course you can set the ip and mask you want, but you have to change the script Vagrantfile.

# Creating
1. run
```
vagrant up
```
2. run
```
kubectl get pods --all-namespaces
```
if everything ok, then cluster is ready

But since it is using host-only network, the cluster can be accessed only by the host machine.

# Destroying
run 
```
vagrant destroy
```
