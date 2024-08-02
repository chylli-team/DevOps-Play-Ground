# DevOps-Play-Ground

it is a script that create a cluster on virtualbox on windows.

# Preparing
1. check your network adapter name that you will bridge to the cluster, and update the Vagrantfile with that name

2. Update ip_segment in Varantfile. The ip will be appended with a index. For example, if ip_segment is '192.168.50.11', then 2 nodes ip will be 192.168.50.111 and 192.168.50.112

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
