# Overview

This project is an example deployment of Zeek in k3d/k3s. Zeek's primary
artifact of interest is it's log files. Each entry represents network
events. For this demo we are side-stepping k8s logging in favor of
a dedicated log processing pipeline for zeek events.
Vector was selected due to it's runtime simplicity, high performance / low-overhead, and flexibility in processing log (and metrics) data, and observability.
Additionally, Vector supports 40 sources, 13 transforms, 50 sinks and [end-to-end-acknowledgements](<https://vector.dev/docs/about/under-the-hood/architecture/end-to-end-acknowledgements/>) which is critical for a class of end users.
For this demo ELK was selected based on ease of setup and deployment thanks to <https://github.com/elastic/cloud-on-k8s>.

## Data flow

* Zeek outputs logs in json (via `LogAscii::use_json=T`)
* Each instance of Zeek has a Vector sidecar. This sidecar is responsible for watching log files in the zeek dir and performing initial transformation via `remap` via [`Vector Remap Language (VRL)`](<https://vector.dev/docs/reference/vrl/>). The transformed logs are sent to a Vector Aggregator.
* Vector Aggregator acts as a dedicated work queue to soak up spikes in load and also as durable storage for logs from the ephemeral Zeek/sidecar workloads.
* Vector Aggregator has a single sink for Zeek logs, in-cluster Elastic Search.
* Vector Aggregator writes to Elastic Search via [Data Streams API](<https://www.elastic.co/guide/en/elasticsearch/reference/8.6/data-streams.html>).
* Elastic can be queried directly or via in-cluster Kibana. See `Access Zeek Logs with Kibana`.

Vector docs call this design [`centralized`](<https://vector.dev/docs/setup/deployment/topologies/#centralized>). Vector can be transitioned to a stream oriented (Kafka/Kinesis) architecture in the future should scaling dictate the additional administrative overhead worthwhile.

# Up and Running

See the tools section for specific versions in use along with known issues and troubleshooting.

## Create a k3s cluster in docker with k3d

YMMV on the resources. ELK is by far the largest consumer of resources. Note that _without_ memory limits every node scheduler will think each _node_ has total RAM availible. Placing a memory limit on all nodes ensures that the scheduler behavior is more realistic. The same it true for CPU as well.

```bash
k3d cluster create sensor -s 3 --servers-memory 4G -a 4 --agents-memory 16G
```
```console
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

## Install Elastic Search


```console
$ kubectl apply -f elastic-deployment/00-crds.yaml
customresourcedefinition.apiextensions.k8s.io/agents.agent.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/apmservers.apm.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/beats.beat.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/elasticmapsservers.maps.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/elasticsearchautoscalers.autoscaling.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/elasticsearches.elasticsearch.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/enterprisesearches.enterprisesearch.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/kibanas.kibana.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/stackconfigpolicies.stackconfigpolicy.k8s.elastic.co created
```
```console
$ kubectl apply -f elastic-deployment/10-operator.yaml
namespace/elastic-system created
serviceaccount/elastic-operator created
secret/elastic-webhook-server-cert created
configmap/elastic-operator created
clusterrole.rbac.authorization.k8s.io/elastic-operator created
clusterrole.rbac.authorization.k8s.io/elastic-operator-view created
clusterrole.rbac.authorization.k8s.io/elastic-operator-edit created
clusterrolebinding.rbac.authorization.k8s.io/elastic-operator created
service/elastic-webhook-server created
statefulset.apps/elastic-operator created
validatingwebhookconfiguration.admissionregistration.k8s.io/elastic-webhook.k8s.elastic.co created
```
```console
$ kubectl apply -f elastic-deployment/40-agent-cluster.yaml
agent.agent.k8s.elastic.co/fleet-server created
kibana.kibana.k8s.elastic.co/quickstart created
elasticsearch.elasticsearch.k8s.elastic.co/quickstart created
clusterrole.rbac.authorization.k8s.io/elastic-agent created
serviceaccount/elastic-agent created
clusterrolebinding.rbac.authorization.k8s.io/elastic-agent created
```

## Install Vector Aggregator

```console
$ kubectl apply -k vector-deployment/.
serviceaccount/vector created
configmap/vector created
service/vector created
service/vector-headless created
statefulset.apps/vector created
```

## Deploy Zeek

This custom image installs `zeek/mitre-attack/bzar` with `zkg`.

```console
$ skaffold run --profile zeek-deployment
Generating tags...
 - zeek/zeek -> zeek/zeek:80b8a7c
Checking cache...
 - zeek/zeek: Found Locally
Starting test...
Tags used in deployment:
 - zeek/zeek -> zeek/zeek:7011a45c668a1856a3891a35981c0c77a03b9bd138ca4d78d5bbdfe4196ff43c
Starting deploy...
Loading images into k3d cluster nodes...
 - zeek/zeek:7011a45c668a1856a3891a35981c0c77a03b9bd138ca4d78d5bbdfe4196ff43c -> Found
Images loaded in 94.874958ms
 - namespace/zeek created
 - configmap/vector-sidecar-b8t59h8t22 created
 - deployment.apps/sensor created
Waiting for deployments to stabilize...
 - zeek:deployment/sensor is ready.
Deployments stabilized in 2.196 seconds
You can also run [skaffold run --tail] to get the logs
```

### Note: `Error from server (ServiceUnavailable)`

If you get this error just run `skaffold run --profile zeek-deployment` again. This appears to be a bug in skaffold. 

```
waiting for deletion: running [kubectl --context k3d-sensor get -f - --ignore-not-found -ojson]
 - stdout: ""
 - stderr: "Error from server (ServiceUnavailable): the server is currently unable to handle the request (get namespaces zeek)\nError from server (ServiceUnavailable): the server is currently unable to handle the request (get configmaps vector-sidecar-b8t59h8t22)\nError from server (ServiceUnavailable): the server is currently unable to handle the request (get deployments.apps sensor)\n"
 - cause: exit status 1
```

## Test Zeek

### Test Zeek Dataplane

```console
$ bash testing/zdp.sh
It should have a conn.log with at least one JSON entry
{"ts":1676501197.719535,"uid":"CDfaFuIhswby4Qv97","id.orig_h":"10.42.4.8","id.orig_p":37249,"id.resp_h":"10.43.0.10","id.resp_p":53,"proto":"udp","service":"dns","duration":0.0004069805145263672,"orig_bytes":100,"resp_bytes":241,"conn_state":"SF","missed_bytes":0,"history":"Dd","orig_pkts":2,"orig_ip_bytes":156,"resp_pkts":2,"resp_ip_bytes":297}
Success!
```

### Test that Logs are exported

```console
$ bash testing/vle.sh ; echo $?
It should get a recent log uid from deployments/sensor
uid=CFrH1a2aH5PVc734y9
It should be in Elastic Search
Handling connection for 9200
false
Handling connection for 9200
false
Handling connection for 9200
false
Handling connection for 9200
false
Handling connection for 9200
false
Handling connection for 9200
false
Handling connection for 9200
false
Handling connection for 9200
false
Handling connection for 9200
true
Success!
0
```

# Access Zeek Logs with Kibana

* Port Forward Kibana
```
$ kubectl port-forward service/quickstart-kb-http 5601
Forwarding from 127.0.0.1:5601 -> 5601
Forwarding from [::1]:5601 -> 5601
```
* Open `https://localhost:5601/` in browser
* Accept TLS warning
* Username: `elastic`
* Password: `kubectl get secret quickstart-es-elastic-user -o go-template='{{.data.elastic | base64decode}}'; echo`

## Kibana: One time setup

* Go to `https://localhost:5601/app/management/kibana/dataViews`
  * `Create data view`
  * Name: `customlogs-generic-default`
  * Pattern: `customlogs-generic-default`
  * Save
  * `Set as Default`
* Go to `https://localhost:5601/app/discover#/`

# Observe Vector log processing

## Open a `top` like TUI for a vector instance.

```bash
kubectl exec vector-0 -i -t -- vector top
```

## Sample logs passing through vector

```console
$ kubectl exec vector-0 -i -t -- vector tap --inputs-of elasticsearch
[tap] Pattern 'elasticsearch' successfully matched.
```
```json
{"file":"/usr/local/zeek/logs/packet_filter.log","host":"sensor","k8s":{"node":{"name":"k3d-sensor-agent-0"},"pod":{"ip":"10.42.5.14","name":"sensor","namespace":"zeek"}},"source_type":"file","timestamp":"2023-02-15T16:29:00.834312026Z","zeek":{"packet_filter":{"filter":"ip or not ip","init":true,"node":"zeek","success":true,"ts":1676478539.841147}}}
{"file":"/usr/local/zeek/logs/conn.log","host":"sensor","k8s":{"node":{"name":"k3d-sensor-agent-0"},"pod":{"ip":"10.42.5.14","name":"sensor","namespace":"zeek"}},"source_type":"file","timestamp":"2023-02-15T16:30:02.330696257Z","zeek":{"connection":{"conn_state":"OTH","duration":0.000017881393432617188,"id.orig_h":"fe80::c08f:f8ff:fe64:7b9c","id.orig_p":143,"id.resp_h":"ff02::16","id.resp_p":0,"missed_bytes":0,"orig_bytes":40,"orig_ip_bytes":152,"orig_pkts":2,"proto":"icmp","resp_bytes":0,"resp_ip_bytes":0,"resp_pkts":0,"ts":1676478539.935714,"uid":"CIWq6P2Ib48tFXxzjh"}}}
```

### vector tap with pretty printed yaml

```console
$ kubectl exec vector-0 -i -t -- vector tap --inputs-of elasticsearch -f yaml
[tap] Pattern 'elasticsearch' successfully matched.
```
```yaml
file: /usr/local/zeek/logs/http.log
host: sensor
k8s:
  node:
    name: k3d-sensor-agent-0
  pod:
    ip: 10.42.5.15
    name: sensor
    namespace: zeek
source_type: file
timestamp: 2023-02-15T16:51:20.816586705Z
zeek:
  http:
    host: deb.debian.org
    id.orig_h: 10.42.5.15
    id.orig_p: 33912
    id.resp_h: 199.232.30.132
    id.resp_p: 80
    method: GET
    request_body_len: 0
    response_body_len: 0
    status_code: 304
    status_msg: Not Modified
    tags: []
    trans_depth: 1
    ts: 1676479878.908009
    uid: CXivoz2Y2ADaaq5rte
    uri: /debian/dists/bullseye/InRelease
    user_agent: Debian APT-HTTP/1.3 (2.2.4)
    version: '1.1'

```

# Cleanup

```console
$ k3d cluster delete sensor 
INFO[0000] Deleting cluster 'sensor'                    
INFO[0004] Deleting cluster network 'k3d-sensor'        
INFO[0005] Deleting 1 attached volumes...               
INFO[0005] Removing cluster details from default kubeconfig... 
INFO[0005] Removing standalone kubeconfig file (if there is one)... 
INFO[0005] Successfully deleted cluster sensor!    
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

```console
$ curl -sLO https://github.com/k3d-io/k3d/releases/download/v5.4.7/k3d-linux-amd64
$ chmod +x k3d-linux-amd64
$ mv k3d-linux-amd64 ~/.local/bin/k3d
```

```console
$ ./k3d-linux-amd64 version
k3d version v5.4.7
k3s version v1.25.6-k3s1 (default)

```

### k3d broken install

Do not `go install` `k3d`. This results in `k3s version v1.21.7-k3s1` instead of `k3s version v1.25.6-k3s1`.

```bash
GOAMD64=v3 CGO_ENABLED=0 GOBIN=~/.local/bin ~/go/bin/go1.19.5  install github.com/k3d-io/k3d/v5@v5.4.7
```

```console
$ k3d version
k3d version v5-dev
k3s version v1.21.7-k3s1 (default)
```


## kubectl


Install kubectl which is k3d/k3s minor version +1.

```console
$ sudo snap install --classic --channel 1.26/stable kubectl
kubectl (1.26/stable) 1.26.1 from Canonical??? installed
```

```console
$ kubectl version -o yaml`
```

```yaml
$ kubectl version -o yaml
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
serverVersion:
  buildDate: "2023-01-26T00:47:47Z"
  compiler: gc
  gitCommit: 9176e03c5788e467420376d10a1da2b6de6ff31f
  gitTreeState: clean
  gitVersion: v1.25.6+k3s1
  goVersion: go1.19.5
  major: "1"
  minor: "25"
  platform: linux/amd64

```

```console
$ kubectl cluster-info
Kubernetes control plane is running at https://0.0.0.0:36023
CoreDNS is running at https://0.0.0.0:36023/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://0.0.0.0:36023/api/v1/namespaces/kube-system/services/https:metrics-server:https/proxy

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

## k9s (optional)

```console
$ curl -ssL https://github.com/derailed/k9s/releases/download/v0.27.3/k9s_Linux_amd64.tar.gz |tar -C ~/.local/bin -xvzf - k9s
```

```console
$ k9s version
 ____  __.________       
|    |/ _/   __   \______
|      < \____    /  ___/
|    |  \   /    /\___ \ 
|____|__ \ /____//____  >
        \/            \/ 

Version:    v0.27.3
Commit:     7c76691c389e4e7de29516932a304f7029307c6d
Date:       2023-02-12T15:19:22Z
```


### Note Snap is no longer updated

```console
$ k9s version
 ____  __.________       
|    |/ _/   __   \______
|      < \____    /  ___/
|    |  \   /    /\___ \ 
|____|__ \ /____//____  >
        \/            \/ 

Version:   0.7.12
Commit:    fe11d334c7929fab7a63cf8703b90d8d2adf1dbb
Date:      2019-07-12T14:26:36Z
```

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
