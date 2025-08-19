{{- define "infra.etcd.serviceURL" }}
{{- if eq .Release.Namespace .Values.kcp.namespace }}
{{- "https://" }}{{ .Values.kcp.etcd.service.name}}:{{.Values.kcp.etcd.service.port}}
{{- else }}
{{- "https://" }}{{ .Values.kcp.etcd.service.name}}.{{ .Values.kcp.namespace}}:{{.Values.kcp.etcd.service.port}}
{{- end }}
{{- end }}}