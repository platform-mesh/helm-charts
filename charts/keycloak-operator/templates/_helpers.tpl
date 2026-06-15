{{- define "keycloak-operator.keycloakImage" -}}
{{- $tag := .Values.keycloakImage.tag | default .Chart.AppVersion -}}
{{- if .Values.keycloakImage.registry -}}
{{- printf "%s/%s:%s" .Values.keycloakImage.registry .Values.keycloakImage.repository $tag -}}
{{- else -}}
{{- printf "%s:%s" .Values.keycloakImage.repository $tag -}}
{{- end -}}
{{- end }}

{{- define "keycloak-operator.watchNamespace" -}}
{{ .Values.watchNamespaces | default .Release.Namespace }}
{{- end }}
