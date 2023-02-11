# Up and Running

See the tools section for specific versions in use along with known issues and troubleshooting.

## Create a k3s cluster in docker with k3d

YMMV on the resources. ELK is by far the largest consumer of resources. Note that _without_ memory limits every node scheduler will think each _node_ has total RAM availible. Placing a memory limit on all nodes ensures that the scheduler behavior is more realistic. The same it true for CPU as well.

```console
$ k3d cluster create sensor -s 3 --servers-memory 4G -a 4 --agents-memory 16G
INFO[0000] Prep: Network                                
INFO[0000] Created network 'k3d-sensor'                 
INFO[0000] Created image volume k3d-sensor-images       
INFO[0000] Starting new tools node...                   
INFO[0000] Creating initializing server node            
INFO[0000] Creating node 'k3d-sensor-server-0'          
INFO[0000] Starting Node 'k3d-sensor-tools'             
INFO[0002] Creating node 'k3d-sensor-server-1'          
INFO[0003] Creating node 'k3d-sensor-server-2'          
INFO[0004] Creating node 'k3d-sensor-agent-0'           
INFO[0005] Creating node 'k3d-sensor-agent-1'           
INFO[0006] Creating node 'k3d-sensor-agent-2'           
INFO[0006] Creating node 'k3d-sensor-agent-3'           
INFO[0007] Creating LoadBalancer 'k3d-sensor-serverlb'  
INFO[0007] Using the k3d-tools node to gather environment information 
INFO[0007] HostIP: using network gateway 172.18.0.1 address 
INFO[0007] Starting cluster 'sensor'                    
INFO[0007] Starting the initializing server...          
INFO[0007] Starting Node 'k3d-sensor-server-0'          
INFO[0010] Starting servers...                          
INFO[0010] Starting Node 'k3d-sensor-server-1'          
INFO[0029] Starting Node 'k3d-sensor-server-2'          
INFO[0045] Starting agents...                           
INFO[0045] Starting Node 'k3d-sensor-agent-1'           
INFO[0045] Starting Node 'k3d-sensor-agent-3'           
INFO[0045] Starting Node 'k3d-sensor-agent-2'           
INFO[0045] Starting Node 'k3d-sensor-agent-0'           
INFO[0054] Starting helpers...                          
INFO[0054] Starting Node 'k3d-sensor-serverlb'          
INFO[0060] Injecting records for hostAliases (incl. host.k3d.internal) and for 8 network members into CoreDNS configmap... 
INFO[0062] Cluster 'sensor' created successfully!       
INFO[0062] You can now use it like this:                
kubectl cluster-info
```
```console
$ kubectl cluster-info 
Kubernetes control plane is running at https://0.0.0.0:42415
CoreDNS is running at https://0.0.0.0:42415/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://0.0.0.0:42415/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

# Runbooks for tools install (and known issues / workarounds)

This is a log of what worked for Ben, on his machine, at the time of install. It also captures any issues/workarounds encountered.

## Environmental Info

Fully patched Ubuntu 20.04 LTS workstation

  * CPU: 16C/32T Threadripper Pro
  * RAM: 128 GB ECC
  * ZFS root
  * "HWE" kernel version: `5.15.0-60-generic` via `linux-image-generic-hwe-20.04`

Call out anything strange about Ben's env for context.

  * Locally built binaries go to `~/.local/bin`. Most people use `/usr/local/bin` for this purpose.
  * `~/go/bin/$goversion` is for concurrently installed go versions.
  * Shell is Bash `5.0.17(1)-release`.

## docker

### ZFS users: `k3d`/`k3s` does not work when Docker storage is `zfs`

* `containerd` _inside_ `k3d` fails to launch containers on ZFS storage.
* `k3s` logs a message like this in the logs:
```
Failed to retrieve agent config: "overlayfs" snapshotter cannot be enabled for "/var/lib/rancher/k3s/agent/containerd", try using "fuse-overlayfs" or "native": failed to mount overlay: invalid argument
```
* see: https://github.com/containerd/containerd/discussions/6140
* In the interest of time I blew away my existing docker env for something well supported.
  * `sudo systemctl stop docker.socket containerd.service`
  * `sudo mv /etc/systemd/system/docker.service.d/override.conf /etc/systemd/system/docker.service.d/.#override.conf`
```
[Unit]
RequiresMountsFor=/var/lib/docker

[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock -s zfs --storage-opt zfs.fsname=rpool/DOCKER/containers
```
  * `sudo systemctl daemon-reload`
  * `sudo zfs destroy -r rpool/DOCKER/containers` (due to `zfs.fsname`)
  * `sudo umount /var/lib/docker`
  * `sudo zfs destroy rpool/DOCKER/var-lib-docker`
  * `sudo zfs create -b 4k -V 100G rpool/DOCKER/var-lib-docker`
  * `sudo mkfs.xfs -b size=4k -n ftype=1  /dev/zvol/rpool/DOCKER/var-lib-docker`
  * `sudo sh -c 'echo "/dev/zvol/rpool/DOCKER/var-lib-docker /var/lib/docker xfs defaults,noatime 0 0" >>/etc/fstab"'`
  * `sudo mount -a`
  * `sudo systemctl start docker.socket containerd.service`
  * `docker version` (see below)
  * `docker info` (see below)

### Working Docker Info

```console
$ docker version
Client:
 Version:           20.10.12
 API version:       1.41
 Go version:        go1.16.2
 Git commit:        20.10.12-0ubuntu2~20.04.1
 Built:             Wed Apr  6 02:14:38 2022
 OS/Arch:           linux/amd64
 Context:           default
 Experimental:      true

Server:
 Engine:
  Version:          20.10.12
  API version:      1.41 (minimum version 1.12)
  Go version:       go1.16.2
  Git commit:       20.10.12-0ubuntu2~20.04.1
  Built:            Thu Feb 10 15:03:35 2022
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          1.5.9-0ubuntu1~20.04.6
  GitCommit:        
 runc:
  Version:          1.1.0-0ubuntu1~20.04.2
  GitCommit:        
 docker-init:
  Version:          0.19.0
  GitCommit:        
```

```console
$ docker info
Client:
 Context:    default
 Debug Mode: false

Server:
 Containers: 0
  Running: 0
  Paused: 0
  Stopped: 0
 Images: 0
 Server Version: 20.10.12
 Storage Driver: overlay2
  Backing Filesystem: xfs
  Supports d_type: true
  Native Overlay Diff: true
  userxattr: false
 Logging Driver: json-file
 Cgroup Driver: cgroupfs
 Cgroup Version: 1
 Plugins:
  Volume: local
  Network: bridge host ipvlan macvlan null overlay
  Log: awslogs fluentd gcplogs gelf journald json-file local logentries splunk syslog
 Swarm: inactive
 Runtimes: runc io.containerd.runc.v2 io.containerd.runtime.v1.linux
 Default Runtime: runc
 Init Binary: docker-init
 containerd version: 
 runc version: 
 init version: 
 Security Options:
  apparmor
  seccomp
   Profile: default
 Kernel Version: 5.15.0-60-generic
 Operating System: Ubuntu 20.04.5 LTS
 OSType: linux
 Architecture: x86_64
 CPUs: 32
 Total Memory: 125.6GiB
 Name: transwarp
 ID: G3PT:SRNI:CIJL:AUNU:QOZZ:Y6KT:JQWU:TUD5:WYZJ:Y6J3:YAI3:LFTD
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 Registry: https://index.docker.io/v1/
 Labels:
 Experimental: false
 Insecure Registries:
  127.0.0.0/8
 Live Restore Enabled: false

```

## k3d


```bash
GOAMD64=v3 CGO_ENABLED=0 GOBIN=~/.local/bin ~/go/bin/go1.19.5  install github.com/k3d-io/k3d/v5@v5.4.7
```

```console
$ k3d version
k3d version v5-dev
k3s version v1.21.7-k3s1 (default)
```

```
$ k3d cluster create sensor
INFO[0000] Prep: Network                                
INFO[0000] Created network 'k3d-sensor'                 
INFO[0000] Created image volume k3d-sensor-images       
INFO[0000] Starting new tools node...                   
INFO[0000] Pulling image 'ghcr.io/k3d-io/k3d-tools:latest' 
INFO[0001] Creating node 'k3d-sensor-server-0'          
INFO[0001] Pulling image 'docker.io/rancher/k3s:v1.21.7-k3s1' 
INFO[0003] Starting Node 'k3d-sensor-tools'             
INFO[0005] Creating LoadBalancer 'k3d-sensor-serverlb'  
INFO[0005] Pulling image 'ghcr.io/k3d-io/k3d-proxy:latest' 
INFO[0009] Using the k3d-tools node to gather environment information 
INFO[0010] HostIP: using network gateway 172.18.0.1 address 
INFO[0010] Starting cluster 'sensor'                    
INFO[0010] Starting servers...                          
INFO[0010] Starting Node 'k3d-sensor-server-0'          
INFO[0014] All agents already running.                  
INFO[0014] Starting helpers...                          
INFO[0014] Starting Node 'k3d-sensor-serverlb'          
INFO[0021] Injecting records for hostAliases (incl. host.k3d.internal) and for 2 network members into CoreDNS configmap... 
INFO[0023] Cluster 'sensor' created successfully!       
INFO[0023] You can now use it like this:                
kubectl cluster-info
```

## kubectl


NOTE: kubectl v1.26.1 does not work with k3d's version of k3s.

```console
E0207 17:27:22.883778 1855235 memcache.go:255] couldn't get resource list for metrics.k8s.io/v1beta1: the server is currently unable to handle the request
```
```console
WARNING: version difference between client (1.26) and server (1.21) exceeds the supported minor version skew of +/-1
```

Install kubectl which is k3d/k3s minor version +1.

```console
$ sudo snap install --classic --channel 1.22/stable kubectl
kubectl (1.22/stable) 1.22.17 from Canonical✓ installed
```

```console
$ kubectl version --client -o yaml`
```

```yaml
clientVersion:
  buildDate: "2023-01-04T19:18:50Z"
  compiler: gc
  gitCommit: a7736eaf34d823d7652415337ac0ad06db9167fc
  gitTreeState: clean
  gitVersion: v1.22.17
  goVersion: go1.16.15
  major: "1"
  minor: "22"
  platform: linux/amd64
serverVersion:
  buildDate: "2021-11-29T16:40:13Z"
  compiler: gc
  gitCommit: ac70570999c566ac3507d2cc17369bb0629c1cc0
  gitTreeState: clean
  gitVersion: v1.21.7+k3s1
  goVersion: go1.16.10
  major: "1"
  minor: "21"
  platform: linux/amd64
```

```console
$ kubectl cluster-info
Kubernetes control plane is running at https://0.0.0.0:45253
CoreDNS is running at https://0.0.0.0:45253/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://0.0.0.0:45253/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

## skaffold

```
$ curl -Lo ~/.local/bin/skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 68.3M  100 68.3M    0     0  53.2M      0  0:00:01  0:00:01 --:--:-- 53.2M
$ chmod +x ~/.local/bin/skaffold
$ skaffold version
v2.1.0

```

## stern (optional)

```bash
GOAMD64=v3 CGO_ENABLED=0 GOBIN=~/.local/bin ~/go/bin/go1.20  install github.com/stern/stern@v1.23.0
```

## helm

```console
$ sudo snap install helm --classic
helm 3.7.0 from Snapcrafters installed
$ helm version
version.BuildInfo{Version:"v3.7.0", GitCommit:"eeac83883cb4014fe60267ec6373570374ce770b", GitTreeState:"clean", GoVersion:"go1.16.8"}
```

## k9s (optional)

```console
$ sudo snap install k9s
```
There's an issue with k9s or the snap. Snap thinks KUBECONFIG is in the snap directory tree.

Run with:

```bash
KUBECONFIG=$HOME/.kube/config k9s
```
Add a shell alias to `~/.bash_aliases`:
```bash
alias k9s='KUBECONFIG=$HOME/.kube/config k9s'
```
