{{- define "kubernetes-graphql-gateway.env" -}}
{{- include "common.basicEnvironment" . }}
- name: OPENAPI_DEFINITIONS_PATH
  value: /app/definitions
- name: LOCAL_DEVELOPMENT
  value: "{{ .Values.localDevelopment | default false }}"
- name: ENABLE_KCP
  value: "{{ (.Values.kcp).enabled }}"
{{- if .Values.kubeConfig.enabled }}
- name: KUBECONFIG
  value: /app/kubeconfig/kubeconfig
{{- end }}
{{- with .Values.extraEnvs }}
{{ toYaml . }}
{{- end }}
{{- end -}}
