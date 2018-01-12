#!/usr/bin/env sh
[ -z "$HTTP_PORT" ] && HTTP_PORT=9000
/usr/bin/curl -sfo /dev/null -d '{"id":1,"method":"slim.request","params":["",["serverstatus"]]}' http://localhost:$HTTP_PORT/jsonrpc.js || exit 1
