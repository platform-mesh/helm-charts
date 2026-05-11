{{- define "keycloak-operator.keycloakImage" -}}
{{ .Values.keycloakImage.repository }}:{{ .Values.keycloakImage.tag | default .Chart.AppVersion }}
{{- end }}

{{- define "keycloak-operator.watchNamespace" -}}
{{ .Values.watchNamespaces | default .Release.Namespace }}
{{- end }}
