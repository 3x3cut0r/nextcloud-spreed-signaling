#!/bin/bash
#
# Standalone signaling server for the Nextcloud Spreed app.
# Copyright (C) 2022 struktur AG
#
# @author Joachim Bauch <bauch@struktur.de>
#
# @license GNU AGPL version 3 or any later version
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
set -e

if [ -z "$CONFIG" ]; then
  echo "No configuration filename given in CONFIG environment variable"
  exit 1
fi

if [ ! -f "$CONFIG" ]; then
  echo "Preparing signaling server configuration in $CONFIG ..."
  cp /config/server.conf.in "$CONFIG"

  if [ ! -z "$HTTP_LISTEN" ]; then
    sed -i "s|#listen = 127.0.0.1:8080|listen = $HTTP_LISTEN|" "$CONFIG"
  fi
  if [ ! -z "$HTTPS_LISTEN" ]; then
    sed -i "s|#listen = 127.0.0.1:8443|listen = $HTTPS_LISTEN|" "$CONFIG"

    if [ ! -z "$HTTPS_CERTIFICATE" ]; then
      sed -i "s|certificate = /etc/nginx/ssl/server.crt|certificate = $HTTPS_CERTIFICATE|" "$CONFIG"
    fi
    if [ ! -z "$HTTPS_KEY" ]; then
      sed -i "s|key = /etc/nginx/ssl/server.key|key = $HTTPS_KEY|" "$CONFIG"
    fi
  fi

  if [ ! -z "$HASH_KEY" ]; then
    sed -i "s|the-secret-for-session-checksums|$HASH_KEY|" "$CONFIG"
  fi
  if [ ! -z "$BLOCK_KEY" ]; then
    sed -i "s|-encryption-key-|$BLOCK_KEY|" "$CONFIG"
  fi
  if [ ! -z "$INTERNAL_SHARED_SECRET_KEY" ]; then
    sed -i "s|the-shared-secret-for-internal-clients|$INTERNAL_SHARED_SECRET_KEY|" "$CONFIG"
  fi
  if [ ! -z "$NATS_URL" ]; then
    sed -i "s|#url = nats://localhost:4222|url = $NATS_URL|" "$CONFIG"
  else
    sed -i "s|#url = nats://localhost:4222|url = nats://loopback|" "$CONFIG"
  fi

  HAS_ETCD=
  if [ ! -z "$ETCD_ENDPOINTS" ]; then
    sed -i "s|#endpoints =.*|endpoints = $ETCD_ENDPOINTS|" "$CONFIG"
    HAS_ETCD=1
  else
    if [ ! -z "$ETCD_DISCOVERY_SRV" ]; then
      sed -i "s|#discoverysrv =.*|discoverysrv = $ETCD_DISCOVERY_SRV|" "$CONFIG"
      HAS_ETCD=1
    fi
    if [ ! -z "$ETCD_DISCOVERY_SERVICE" ]; then
      sed -i "s|#discoveryservice =.*|discoveryservice = $ETCD_DISCOVERY_SERVICE|" "$CONFIG"
    fi
  fi
  if [ ! -z "$HAS_ETCD" ]; then
    if [ ! -z "$ETCD_CLIENT_KEY" ]; then
      sed -i "s|#clientkey = /path/to/etcd-client.key|clientkey = $ETCD_CLIENT_KEY|" "$CONFIG"
    fi
    if [ ! -z "$ETCD_CLIENT_CERTIFICATE" ]; then
      sed -i "s|#clientcert = /path/to/etcd-client.crt|clientcert = $ETCD_CLIENT_CERTIFICATE|" "$CONFIG"
    fi
    if [ ! -z "$ETCD_CLIENT_CA" ]; then
      sed -i "s|#cacert = /path/to/etcd-ca.crt|cacert = $ETCD_CLIENT_CA|" "$CONFIG"
    fi
  fi

  if [ ! -z "$USE_JANUS" ]; then
    sed -i "s|#type =$|type = janus|" "$CONFIG"
    if [ ! -z "$JANUS_URL" ]; then
      sed -i "/proxy URLs to connect to/{n;s|#url =$|url = $JANUS_URL|}" "$CONFIG"
    fi
  elif [ ! -z "$USE_PROXY" ]; then
    sed -i "s|#type =$|type = proxy|" "$CONFIG"

    if [ ! -z "$PROXY_ETCD" ]; then
      if [ -z "$HAS_ETCD" ]; then
        echo "No etcd endpoint configured, can't use etcd for proxy connections"
        exit 1
      fi

      sed -i "s|#urltype = static|urltype = etcd|" "$CONFIG"

      if [ ! -z "$PROXY_TOKEN_ID" ]; then
        sed -i "s|#token_id =.*|token_id = $PROXY_TOKEN_ID|" "$CONFIG"
      fi
      if [ ! -z "$PROXY_TOKEN_KEY" ]; then
        sed -i "s|#token_key =.*|token_key = $PROXY_TOKEN_KEY|" "$CONFIG"
      fi
      if [ ! -z "$PROXY_KEY_PREFIX" ]; then
        sed -i "s|#keyprefix =.*|keyprefix = $PROXY_KEY_PREFIX|" "$CONFIG"
      fi
    else
      if [ ! -z "$PROXY_URLS" ]; then
        sed -i "/proxy URLs to connect to/{n;s|#url =$|url = $PROXY_URLS|}" "$CONFIG"
      fi
      if [ ! -z "$PROXY_DNS_DISCOVERY" ]; then
        sed -i "/or deleted as necessary/{n;s|#dnsdiscovery =.*|dnsdiscovery = true|}" "$CONFIG"
      fi
    fi
  fi

  if [ ! -z "$MAX_STREAM_BITRATE" ]; then
    sed -i "s|#maxstreambitrate =.*|maxstreambitrate = $MAX_STREAM_BITRATE|" "$CONFIG"
  fi
  if [ ! -z "$MAX_SCREEN_BITRATE" ]; then
    sed -i "s|#maxscreenbitrate =.*|maxscreenbitrate = $MAX_SCREEN_BITRATE|" "$CONFIG"
  fi

  if [ ! -z "$TURN_API_KEY" ]; then
    sed -i "s|the-api-key-for-the-rest-service|$TURN_API_KEY|" "$CONFIG"
  fi
  if [ ! -z "$TURN_SECRET" ]; then
    sed -i "s|6d1c17a7-c736-4e22-b02c-e2955b7ecc64|$TURN_SECRET|" "$CONFIG"
  fi
  if [ ! -z "$TURN_SERVERS" ]; then
    sed -i "s|#servers =.*|servers = $TURN_SERVERS|" "$CONFIG"
  fi

  if [ ! -z "$GEOIP_LICENSE" ]; then
    sed -i "s|#license =.*|license = $GEOIP_LICENSE|" "$CONFIG"
  fi
  if [ ! -z "$GEOIP_URL" ]; then
    sed -i "/looking up IP addresses/{n;s|#url =$|url = $GEOIP_URL|}" "$CONFIG"
  fi

  if [ ! -z "$STATS_IPS" ]; then
    sed -i "s|#allowed_ips =.*|allowed_ips = $STATS_IPS|" "$CONFIG"
  fi

  if [ ! -z "$GRPC_LISTEN" ]; then
    sed -i "s|#listen = 0.0.0.0:9090|listen = $GRPC_LISTEN|" "$CONFIG"

    if [ ! -z "$GRPC_SERVER_CERTIFICATE" ]; then
      sed -i "s|#servercertificate =.*|servercertificate = $GRPC_SERVER_CERTIFICATE|" "$CONFIG"
    fi
    if [ ! -z "$GRPC_SERVER_KEY" ]; then
      sed -i "s|#serverkey =.*|serverkey = $GRPC_SERVER_KEY|" "$CONFIG"
    fi
    if [ ! -z "$GRPC_SERVER_CA" ]; then
      sed -i "s|#serverca =.*|serverca = $GRPC_SERVER_CA|" "$CONFIG"
    fi
    if [ ! -z "$GRPC_CLIENT_CERTIFICATE" ]; then
      sed -i "s|#clientcertificate =.*|clientcertificate = $GRPC_CLIENT_CERTIFICATE|" "$CONFIG"
    fi
    if [ ! -z "$GRPC_CLIENT_KEY" ]; then
      sed -i "s|#clientkey = /path/to/grpc-client.key|clientkey = $GRPC_CLIENT_KEY|" "$CONFIG"
    fi
    if [ ! -z "$GRPC_CLIENT_CA" ]; then
      sed -i "s|#clientca =.*|clientca = $GRPC_CLIENT_CA|" "$CONFIG"
    fi
    if [ ! -z "$GRPC_ETCD" ]; then
      if [ -z "$HAS_ETCD" ]; then
        echo "No etcd endpoint configured, can't use etcd for GRPC"
        exit 1
      fi

      sed -i "s|#targettype =$|targettype = etcd|" "$CONFIG"

      if [ ! -z "$GRPC_TARGET_PREFIX" ]; then
        sed -i "s|#targetprefix =.*|targetprefix = $GRPC_TARGET_PREFIX|" "$CONFIG"
      fi
    else
      if [ ! -z "$GRPC_TARGETS" ]; then
        sed -i "s|#targets =.*|targets = $GRPC_TARGETS|" "$CONFIG"

        if [ ! -z "$GRPC_DNS_DISCOVERY" ]; then
          sed -i "/# deleted as necessary/{n;s|#dnsdiscovery =.*|dnsdiscovery = true|}" "$CONFIG"
        fi
      fi
    fi
  fi

  if [ ! -z "$GEOIP_OVERRIDES" ]; then
    sed -i "s|\[geoip-overrides\]|#[geoip-overrides]|" "$CONFIG"
    echo >> "$CONFIG"
    echo "[geoip-overrides]" >> "$CONFIG"
    for override in $GEOIP_OVERRIDES; do
      echo $override >> "$CONFIG"
    done
    echo >> "$CONFIG"
  fi

  if [ ! -z "$CONTINENT_OVERRIDES" ]; then
    sed -i "s|\[continent-overrides\]|#[continent-overrides]|" "$CONFIG"
    echo >> "$CONFIG"
    echo "[continent-overrides]" >> "$CONFIG"
    for override in $CONTINENT_OVERRIDES; do
      echo $override >> "$CONFIG"
    done
    echo >> "$CONFIG"
  fi

  if [ ! -z "$BACKENDS" ]; then
    sed -i "s|#backends = .*|backends = $BACKENDS|" "$CONFIG"

    echo >> "$CONFIG"
    for backend in $BACKENDS; do
      echo "[$backend]" >> "$CONFIG"

      declare var="BACKEND_${backend^^}_URL"
      if [ ! -z "${!var}" ]; then
        echo "url = ${!var}" >> "$CONFIG"
      fi

      declare var="BACKEND_${backend^^}_SHARED_SECRET"
      if [ ! -z "${!var}" ]; then
        echo "secret = ${!var}" >> "$CONFIG"
      fi

      declare var="BACKEND_${backend^^}_SESSION_LIMIT"
      if [ ! -z "${!var}" ]; then
        echo "sessionlimit = ${!var}" >> "$CONFIG"
      fi

      declare var="BACKEND_${backend^^}_MAX_STREAM_BITRATE"
      if [ ! -z "${!var}" ]; then
        echo "maxstreambitrate = ${!var}" >> "$CONFIG"
      fi

      declare var="BACKEND_${backend^^}_MAX_SCREEN_BITRATE"
      if [ ! -z "${!var}" ]; then
        echo "maxscreenbitrate = ${!var}" >> "$CONFIG"
      fi
      echo >> "$CONFIG"
    done
  fi
fi

echo "Starting signaling server with $CONFIG ..."
exec "$@"
