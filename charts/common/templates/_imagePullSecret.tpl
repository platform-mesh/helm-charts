{{- define "common.imagePullSecret" }}
imagePullSecrets:
  - name: {{ include "common.getKeyValue" (dict "Values" .Values "key" "imagePullSecret") }}
{{- end -}}