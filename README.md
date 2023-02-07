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

