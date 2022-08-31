#!/bin/bash
#
#
. common_funcs

[[ "$ENGINE" ]] || die "No engine"

echo "Setup default cluster"
echo "Add hosts"
for i in $HOSTS; do
    curl_api /hosts -d "<host><name>$i</name><address>$i</address><ssh><authentication_method>publickey</authentication_method></ssh></host>"
done
