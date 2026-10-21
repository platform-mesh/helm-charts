{{/*
  Function: common.gateway.corsFilter
  Description:
    Emits the HTTPRoute CORS filter entry (a single list item) in a
    gateway-implementation-agnostic way, driven by the `cors.mode` value:

      - native       : emit the upstream Gateway API `type: CORS` filter built
                       from cors.allowOrigins/allowMethods/allowHeaders/
                       allowCredentials/maxAge (portable; honored by controllers
                       that implement GEP-1767).
      - none / ""    : emit nothing.

    Values are resolved through common.getKeyValue so override/global/chart/
    default precedence applies, and a chart can supply its own cors block.

  Parameters:
    - . : the root context (passed as the whole dot).

  Usage (inside an existing `filters:` block):
    {{- include "common.gateway.corsFilter" . | nindent 4 }}
*/}}
{{- define "common.gateway.corsFilter" -}}
{{- $mode := include "common.getKeyValue" (dict "Values" .Values "key" "cors.mode") -}}
{{- if eq $mode "native" }}
{{- /* Merge chart-level .Values.cors over the common chart defaults so native-mode
     fields (allowMethods/allowHeaders/...) resolve even when a chart only sets
     cors.mode. */ -}}
{{- $defaults := dict -}}
{{- if .Values.common }}{{- if .Values.common.defaults }}{{- with .Values.common.defaults.cors }}{{- $defaults = . }}{{- end }}{{- end }}{{- end }}
{{- $cors := merge (deepCopy (.Values.cors | default dict)) $defaults -}}
- type: CORS
  cors:
    {{- with $cors.allowOrigins }}
    allowOrigins:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $cors.allowMethods }}
    allowMethods:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $cors.allowHeaders }}
    allowHeaders:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $cors.exposeHeaders }}
    exposeHeaders:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- if hasKey $cors "allowCredentials" }}
    allowCredentials: {{ $cors.allowCredentials }}
    {{- end }}
    {{- if $cors.maxAge }}
    maxAge: {{ $cors.maxAge }}
    {{- end }}
{{- end }}
{{- end -}}

{{/*
  Function: common.gateway.corsEnabled
  Description:
    Returns "true" when a CORS filter should be rendered (cors.mode is
    "native"), else "". Lets templates decide whether to open a `filters:` block.
*/}}
{{- define "common.gateway.corsEnabled" -}}
{{- $mode := include "common.getKeyValue" (dict "Values" .Values "key" "cors.mode") -}}
{{- if and $mode (ne $mode "none") -}}
true
{{- end -}}
{{- end -}}
