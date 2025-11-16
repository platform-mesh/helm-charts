{{/*
Recursively search a map for a key named "hostAliases" with a null value
and replace it with the global .Values.hostAliases list.
*/}}
{{- define "hostaliases.injectGlobalHostAliases" -}}
  {{- $dict := .dict -}}
  {{- $root := .root -}}
  {{- range $key, $value := $dict -}}
    {{- if eq $key "hostAliases" -}}
      {{- if not $value -}}
        {{- /* If key is hostAliases and value is null/falsy, replace it */ -}}
        {{- $_ := set $dict $key $root.Values.hostAliases -}}
      {{- end -}}
    {{- else if (kindIs "map" $value) -}}
      {{- /* If value is another map, recurse into it */ -}}
      {{- $_ := include "hostaliases.injectGlobalHostAliases" (dict "dict" $value "root" $root) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
