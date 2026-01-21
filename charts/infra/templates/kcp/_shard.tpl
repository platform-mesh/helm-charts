{{/*
  Function: kcpShardCommonValues
  Description: This function returns common values for kcp root shard/shard configuration.
  Parameters: The values object ($).
*/}}
{{- define "kcpShardCommonValues" -}}
  replicas: {{ $.Values.kcp.shards.replicas }}
  {{ with $.Values.kcp.image.tag }}
  proxy:
    image:
      tag: {{ . }}
  {{- end }}
  {{- if $.Values.kcp.oidc.enabled }}
  auth:
    {{ with $.Values.kcp.oidc }}
    oidc:
      enabled: true
      issuerURL: {{ .issuerUrl }}
      caFileRef:
        name: {{ .caFileRef.name }}
        key: {{ .caFileRef.key }}
      clientID: {{ .clientID }}
      groupsClaim: {{ .groupsClaim }}
      usernameClaim: {{ .usernameClaim }}
    {{- end }}
  {{- end }}
  external:
    # replace the hostname with the external DNS name for your kcp instance
    hostname: {{ $.Values.kcp.external.hostname }}
    port: {{ $.Values.kcp.external.port }}
  {{- if ($.Values.kcp.webhook).enabled }}
  authorization:
    webhook:
      configSecretName: {{ $.Values.kcp.webhook.authorizationWebhookSecretName }}
  {{- end }}
  certificates:
    # this references the issuer created above
    issuerRef:
      group: cert-manager.io
      kind: Issuer
      name: selfsigned
  cache:
    embedded:
      # kcp comes with a cache server accessible to all shards,
      # in this case it is fine to enable the embedded instance
      enabled: true
  etcd:
    endpoints:
      # this is the service URL to etcd. Replace if Helm chart was
      # installed under a different name or the namespace is not "default"
      - http://{{ $.Values.kcp.etcd.service.name}}.{{ $.Values.kcp.namespace}}.svc.cluster.local:{{ $.Values.kcp.etcd.service.port }}
  {{ with $.Values.kcp.image.tag }}
  image:
    tag: {{ . }}
  {{- end }}
  deploymentTemplate:
    spec:
      template:
        metadata:
          annotations:
            # this excludes webhook traffic from the istio sidecar
            traffic.sidecar.istio.io/excludeOutboundPorts: "{{ $.Values.kcp.webhook.port }}"
        spec:
        {{ include "common.hostAliases" $ | nindent 10 }}
  extraArgs:
{{ toYaml $.Values.kcp.shards.extraArgs | indent 4 }}
{{- end }}
