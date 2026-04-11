{{- define "keycloak-operator.name" -}}
keycloak-operator
{{- end }}

{{- define "keycloak-operator.labels" -}}
app.kubernetes.io/name: {{ include "keycloak-operator.name" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "keycloak-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "keycloak-operator.name" . }}
{{- end }}

{{- define "keycloak-operator.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}
{{- end }}

{{- define "keycloak-operator.keycloakImage" -}}
{{ .Values.keycloakImage.repository }}:{{ .Values.keycloakImage.tag | default .Chart.AppVersion }}
{{- end }}

{{- define "keycloak-operator.watchNamespace" -}}
{{ .Values.watchNamespaces | default .Release.Namespace }}
{{- end }}

