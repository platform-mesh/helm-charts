{{- /*
Render hostAliases using lookup order:
1. deployment.hostAliasesOverride
2. global.deployment.hostAliases
3. deployment.hostAliases
4. defaults.deployment.hostAliases

Each of these keys is expected to be an array; if the chosen one is empty or unset, render nothing.
*/ -}}
{{- define "common.hostAliases" -}}
{{- $v := .Values -}}
{{- $aliases := list -}}

{{- if and $v.deployment (hasKey $v.deployment "hostAliasesOverride") -}}
  {{- $aliases = index $v.deployment "hostAliasesOverride" -}}
{{- else if and $v.global $v.global.deployment (hasKey $v.global.deployment "hostAliases") -}}
  {{- $aliases = index $v.global.deployment "hostAliases" -}}
{{- else if and $v.deployment (hasKey $v.deployment "hostAliases") -}}
  {{- $aliases = index $v.deployment "hostAliases" -}}
{{- else if and $v.defaults $v.defaults.deployment (hasKey $v.defaults.deployment "hostAliases") -}}
  {{- $aliases = index $v.defaults.deployment "hostAliases" -}}
{{- end }}

{{- if and $aliases (gt (len $aliases) 0) -}}
hostAliases:
{{- toYaml $aliases | nindent 6 }}
{{- end -}}
{{- end }}
