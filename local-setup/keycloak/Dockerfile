FROM quay.io/keycloak/keycloak:26.6.0 AS builder

ENV KC_DB=postgres
ENV KC_HTTP_RELATIVE_PATH=/keycloak/
ENV KC_PROXY_HEADERS=xforwarded
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:26.6.0

COPY --from=builder /opt/keycloak/ /opt/keycloak/

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
