{{- /*
Render hostAliases using lookup order:
1. hostAliasesOverride
2. global.hostAliases
3. hostAliases
4. defaults.hostAliases

Each of these keys is expected to be an array, or a map with "enabled" and "entries" keys.
If the chosen one is empty or unset, render nothing.
*/ -}}
{{- define "common.hostAliases" -}}
{{- $v := .Values -}}
{{- $source := dict -}}
{{- $aliases := list -}}

{{- if and $v (hasKey $v "hostAliasesOverride") -}}
  {{- $source = index $v "hostAliasesOverride" -}}
{{- else if and $v.global (hasKey $v.global "hostAliases") -}}
  {{- $source = index $v.global "hostAliases" -}}
{{- else if and $v (hasKey $v "hostAliases") -}}
  {{- $source = index $v "hostAliases" -}}
{{- else if and $v.defaults (hasKey $v.defaults "hostAliases") -}}
  {{- $source = index $v.defaults "hostAliases" -}}
{{- end }}

{{- if $source -}}
  {{- if kindIs "slice" $source -}}
    {{- $aliases = $source -}}
  {{- else if and (kindIs "map" $source) (default true $source.enabled) -}}
    {{- $aliases = $source.entries | default list -}}
  {{- end -}}
{{- end -}}

{{- if and $aliases (gt (len $aliases) 0) -}}
hostAliases:
{{- toYaml $aliases | nindent 8 }}
{{- end -}}
{{- end }}
