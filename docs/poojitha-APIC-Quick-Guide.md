# APIC quick install
The document below uses the steps outlined in the repo [APIC-Quick-Guide](https://github.com/morningspace/lab-k8s-playground/blob/dev/docs/APIC-Quick-Guide.md) and addresses the issues one might encounter during the install. Follow the steps given in this doc in conjuction with the original document

NOTE: APIC installed using this process cannot be installed for production purposes. This is only designed for quick testing locally

### Step 1 - Initialize the playground
- Clone the dev branch from the repo (Master has some issues that are fixed in dev branch)
    ```
    $ git clone -b dev  https://github.com/morningspace/lab-k8s-playground.git
    $ cd lab-k8s-playground
    $ ./install/launch.sh init
    ```
After running the init command, edit ~/.bashrc accordingly as mentioned in [original document](https://github.com/morningspace/lab-k8s-playground/blob/dev/docs/APIC-Quick-Guide.md)


- `$ vi ~/.bashrc`
- Update `HOST_IP` to use your VSI's IP
- Update `NUM_NODES` to `3` if deploying to a kube-enviroment set by the `lab-k8s-playground`
- Look into the orginal document for details
- Reload `.bashrc` to apply changes - Run `$ . ~/.bashrc`
### Step 2 - Prepare APIC installation packages

````
$ echo $LAB_HOME
$ cd $LAB_HOME/install/.launch-cache
$ mkdir apic

````
NOTE: Refer to the offcial APIC documentation [First steps for installing API Connect: Upload files to registry] (https://www.ibm.com/support/knowledgecenter/en/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_Kubernetes_firststeps.html)  for info on downloading the required packages. This document does not provide additional details on how to get the images.
If you have your files stored in a remote file storage, follow steps in the next section. Otherwise, skip the steps below and copy your images to the specified directory.
#### Mounting file storage
Mount the file storage on the boot node at path $LAB_HOME/install/.launch-cache/apic/


 - Make sure to [authorize your host](https://cloud.ibm.com/docs/infrastructure/FileStorage?topic=FileStorage-managingstorage#authorizing-hosts-to-access-file-storage) to use the file storage before mounting.  
 - `$ sudo apt-get update && apt-get install nfs-common`
 - `$ mount -t nfs -o hard,intr <mount_point>  $LAB_HOME/install/.launch-cache/apic`
 If IBM file storage is used, mount point will look something like `nfsdal0501a.service.softlayer.com:/IBM01SV278685_7/data01`
 -  Add below line by doing `$ vi /etc/fstab`
    ````
    <mount_point> /root/lab-k8s-playground/install/.launch-cache/apic nfs4 defaults,hard,intr 0       0
    ````
-  `$ mount -fav`
#### Check for images
- Check if you have all the files 
    ````
    $ ls -1 $LAB_HOME/install/.launch-cache/apic/`

    analytics-images-kubernetes_lts_v2018.4.1.7-ifix1.5.tgz
    apicup-linux_lts_v2018.4.1.7-ifix1.5
    dpm2018417.lts.tar.gz
    idg_dk2018417.lts.nonprod.tar.gz
    management-images-kubernetes_lts_v2018.4.1.7-ifix1.5.tgz
    portal-images-kubernetes_lts_v2018.4.1.7-ifix1.5.tgz
    ````

### Step 3 - Change and review APIC settings

If this is not your first install on the same VM, you don't have to load images again. 
Set `apic_skip_load_images=1`

Change the below values accordingly. 
For example,
```
apic_domain=${apic_domain:-phoenix.com}
gwy_image_tag=2018.4.1.7-312001-nonprod
````

### Step 4 - Launch API Connect

#### Launch Kubernetes Environment
````
$ launch default
````

Issue occurred:
````
» Take other registries up...
ERROR: Network net-registries declared as external, but could not be found. Please create the network manually using `docker network create net-registries` and try again.
````
````
* Starting DIND container: kube-master
Error response from daemon: network net-registries not found
````
Followed the suggestion from the error message above to resolve and re-launched 
````
$ docker network create net-registries
$ launch default

````
Now, the registry should be up. You'll see the following on the console output
```
» Take registry mr.io up...
Pulling mr.io (registry:2)...
2: Pulling from library/registry
c87736221ed0: Pull complete
1cc8e0bb44df: Pull complete
54d33bcb37f5: Pull complete
e8afc091c171: Pull complete
b4541f6d3db6: Pull complete
Digest: sha256:8004747f1e8cd820a148fb7499d71a76d45ff66bac6a29129bfdbfdc0154d146
Status: Downloaded newer image for registry:2
Creating mr.io ... done
```
Run ` kubectl version` to verify if everything is working as expected

You can also verify the nodes
```
$ kubectl get nodes
NAME          STATUS   ROLES    AGE     VERSION
kube-master   Ready    master   2m45s   v1.14.4
kube-node-1   Ready    <none>   107s    v1.14.4
kube-node-2   Ready    <none>   106s    v1.14.4
kube-node-3   Ready    <none>   106s    v1.14.4
```
#### Launch APIC

```
$ launch apic
```

Approx Time taken - 30 mins (images upload about 10-15 mins)

Verify running pods
```
$ kubectl get pods -n apiconnect

r554d996560-datapower-monitor-ccbcf8cbc-8dt8v                 0/1     ImagePullBackOff   0          20m
r554d996560-dynamic-gateway-service-0                         0/1     Init:0/1           0          20m
```
#### Datapower Monitor Pod Issue
```
$ kubectl describe pod r554d996560-datapower-monitor-ccbcf8cbc-8dt8v -n apiconnect
Back-off pulling image "mr.io:5000/k8s-datapower-monitor:2018.4.1-9-00bcbcf"
```
Reason - Original doc is written to handle APIC `v2018.4.1.4`. We are using `v2018.4.1.7`. With this version, a new monitor pod was introduced. More details [here](https://www.ibm.com/support/knowledgecenter/en/SSMNED_2018/com.ibm.apic.overview.doc/overview_whatsnew_417.html)

So, we need to load the image into the local registry and make sure the deployment uses the right tag. Follow steps below:

```
$ docker load -i $LAB_HOME/install/.launch-cache/apic/dpm2018417.lts.tar.gz
$ docker tag ibmcom/k8s-datapower-monitor:2018.4.1.7 127.0.0.1:5000/k8s-datapower-monitor
$ docker push 127.0.0.1:5000/k8s-datapower-monitor
```
```
$ kubectl get deployments -n apiconnect

$ kubectl edit deployment r554d996560-datapower-monitor -n apiconnect -o yaml
```
- Update image in container `datapower-monitor` to `image: mr.io:5000/k8s-datapower-monitor`
-  You may notice an error like the below 
    ```
    error: map: map[] does not contain declared merge key: name
    ```
    Delete `imagePullSecrets` key and it's value from the deployment yaml(Only if it's empty (`[]`)) while editing the deployment to resolve this error

#### Datapower Monitor Pod Issue    

Now, check for pods again `$ kubectl get pods -n apiconnect`. You may notice the gateway service pod is still failing
```

r554d996560-dynamic-gateway-service-0                         0/1     ImagePullBackOff   0          45m
```
This pod is generated by statefulset `r554d996560-dynamic-gateway-service`. 

Perform a rolling update to the stateful set to make it use the image with the correct tag. 
The tag we use here should match the value supplied for `gwy_image_tag` in file `$LAB_HOME/install/targets/apic/settings.sh`  
Eg: `gwy_image_tag=2018.4.1.7.312001-nonprod` 

```
$ kubectl get statefulsets -n apiconnect

$ kubectl patch statefulset r554d996560-dynamic-gateway-service -n apiconnect -p '{"spec":{"updateStrategy":{"type":"RollingUpdate"}}}'

$ kubectl patch statefulset r554d996560-dynamic-gateway-service --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"mr.io:5000/datapower-api-gateway:2018.4.1.7-312001-nonprod"}]' -n apiconnect
```
   
Delete the dynamic gateway service pod so that a new pod will be created with the above applied patch
```
$ kubectl delete pod r554d996560-dynamic-gateway-service-0  -n apiconnect

```
Now, all pods should be in `Running` or `Completed` state.
Check using `$ kubectl get pods -n apiconnect`


### Step 5: Expose APIC endpoints


- `$ launch apic::expose`
- `$ vi /etc/hosts`

    Add line to the file 
    ```
    <HOST_IP> cm.phoenix.com gwd.phoenix.com gw.phoenix.com padmin.phoenix.com portal.phoenix.com ac.phoenix.com apim.phoenix.com api.phoenix.com
    ```
    NOTE: If the install is done on VSI and not on your local machine, edit the hosts file on your machine to access the ednpoint `https://cm.phoenix.com` from your local browser 
- Run `$ launch endpoints`

    ```
    Targets to be launched: [endpoints]
    ####################################
    # Launch target endpoints...
    ####################################
    Apic:
    ✔ Gateway Management Endpoint  : https://gwd.phoenix.com 
    ? Gateway API Endpoint Base    : https://gw.phoenix.com 
    ✔ Portal Management Endpoint   : https://padmin.phoenix.com 
    ✔ Portal Website URL           : https://portal.phoenix.com 
    ✔ Analytics Management Endpoint: https://ac.phoenix.com 
    ✔ Cloud Manager UI             : https://cm.phoenix.com (default usr/pwd: admin/<password>)
  ```

At this point all endpoints should be up except for the `Gateway API Endpoint Base`. This will be up after the configuring the services through Cloud Manager UI.
  
Follow the steps show in this [video](https://github.com/morningspace/lab-k8s-playground/blob/dev/docs/demo-apic.gif) to configure the services.

