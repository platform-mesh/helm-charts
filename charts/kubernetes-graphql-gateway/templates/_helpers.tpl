{{- define "kubernetes-graphql-gateway.env" -}}
{{- include "common.basicEnvironment" . }}
{{- if .Values.kubeConfig.enabled }}
- name: KUBECONFIG
  value: {{ .Values.kubeConfig.path }}
{{- end }}
{{- end -}}
