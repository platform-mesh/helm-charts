{{- define "kcp.etcd" -}}
apiVersion: druid.gardener.cloud/v1alpha1
kind: Etcd
metadata:
  name: {{ .name }}
  namespace: {{ .namespace }}
  labels:
    app: etcd-statefulset
    gardener.cloud/role: controlplane
    role: kcp
spec:
  annotations:
    app: etcd-statefulset
    gardener.cloud/role: controlplane
    role: kcp
  labels:
    app: etcd-statefulset
    gardener.cloud/role: controlplane
    role: kcp
  etcd:
    metrics: basic
    defragmentationSchedule: {{ .etcd.defragmentationSchedule | default "\"0 */24 * * *\"" }}
    resources:
      limits:
        cpu: {{ .etcd.resources.limits.cpu | default "500m" }}
        memory: {{ .etcd.resources.limits.memory | default "1Gi" }}
      requests:
        cpu: {{ .etcd.resources.requests.cpu | default "100m" }}
        memory: {{ .etcd.resources.requests.memory | default "200Mi" }}
    clientPort: {{ .etcd.service.port | default 2379 }}
    serverPort: {{ .etcd.serverPort | default 2380 }}
    quota: {{ .etcd.quota | default "8Gi" }}
  backup:
    port: {{ .etcd.backup.port | default 8080 }}
    fullSnapshotSchedule: {{ .etcd.backup.fullSnapshotSchedule | default "\"0 */24 * * *\"" }}
    resources:
      limits:
        cpu: {{ .etcd.backup.resources.limits.cpu | default "200m" }}
        memory: {{ .etcd.backup.resources.limits.memory | default "1Gi" }}
      requests:
        cpu: {{ .etcd.backup.resources.requests.cpu | default "23m" }}
        memory: {{ .etcd.backup.resources.requests.memory | default "128Mi" }}
    garbageCollectionPolicy: {{ .etcd.backup.garbageCollectionPolicy | default "Exponential" }}
    garbageCollectionPeriod: {{ .etcd.backup.garbageCollectionPeriod | default "43200s" }}
    deltaSnapshotPeriod: {{ .etcd.backup.deltaSnapshotPeriod | default "300s" }}
    deltaSnapshotMemoryLimit: {{ .etcd.backup.deltaSnapshotMemoryLimit | default "1Gi" }}
    compression:
      enabled: {{ .etcd.backup.compression.enabled | default false }}
      policy: {{ .etcd.backup.compression.policy | default "\"gzip\"" }}
    leaderElection:
      reelectionPeriod: {{ .etcd.backup.leaderElection.reelectionPeriod | default "5s" }}
      etcdConnectionTimeout: {{ .etcd.backup.leaderElection.etcdConnectionTimeout | default "5s" }}
{{- if .etcd.backup.store }}
    store:
{{ toYaml .etcd.backup.store | indent 6 }}
{{- end }}

  sharedConfig:
    autoCompactionMode: {{ .etcd.sharedConfig.autoCompactionMode | default "periodic" }}
    autoCompactionRetention: {{ .etcd.sharedConfig.autoCompactionRetention | default "\"30m\"" }}


  replicas: {{ .etcd.replicas | default 1 }}
{{- end -}}
{{- define "kcp.tlsroute" -}}
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: {{ .name }}
  namespace: {{ .namespace }}
spec:
  hostnames:
  - {{ .hostname }}
  parentRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: {{ .gatewayName }}
    sectionName: passthrough
  rules:
  - backendRefs:
    - group: ""
      kind: Service
      name: {{ .serviceName }}
      namespace: {{ .namespace }}
      port: 6443
{{- end -}}
