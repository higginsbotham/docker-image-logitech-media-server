#!/bin/sh
[ -z "$HTTP_PORT" ] && HTTP_PORT=9000
wget -qO- --post-data '{"id":1,"method":"slim.request","params":["",["serverstatus"]]}' http://localhost:$HTTP_PORT/jsonrpc.js || exit 1
