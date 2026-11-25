#!/bin/sh
set -eu
id="${WEB_GOOGLE_CLIENT_ID:-}"
case "$id" in
  '') ;;
  *[!a-zA-Z0-9._-]*) echo "Invalid WEB_GOOGLE_CLIENT_ID" >&2; exit 1 ;;
  *.apps.googleusercontent.com) ;;
  *) echo "Invalid WEB_GOOGLE_CLIENT_ID" >&2; exit 1 ;;
esac
printf '{"googleClientId":"%s"}\n' "$id" > /usr/share/nginx/html/config.json
