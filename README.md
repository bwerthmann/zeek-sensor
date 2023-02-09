# Install needed tools

## k3d

NOTE: k3d does not support docker volumes backed by ZFS storage.

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

# stern (optional dev tool)

```bash
GOAMD64=v3 CGO_ENABLED=0 GOBIN=~/.local/bin ~/go/bin/go1.20  install github.com/stern/stern@v1.23.0
```

# helm

```console
$ sudo snap install helm --classic
helm 3.7.0 from Snapcrafters installed
$ helm version
version.BuildInfo{Version:"v3.7.0", GitCommit:"eeac83883cb4014fe60267ec6373570374ce770b", GitTreeState:"clean", GoVersion:"go1.16.8"}
```
