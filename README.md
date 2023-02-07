# Install needed tools

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

```console
$ sudo sudo snap install kubectl --classic
kubectl 1.26.1 from Canonical✓ installed
```

```console
$ kubectl version --client -o yaml`
```

```yaml
clientVersion:
  buildDate: "2023-01-19T02:26:55Z"
  compiler: gc
  gitCommit: 8f94681cd294aa8cfd3407b8191f6c70214973a4
  gitTreeState: clean
  gitVersion: v1.26.1
  goVersion: go1.19.5
  major: "1"
  minor: "26"
  platform: linux/amd64
kustomizeVersion: v4.5.7
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

