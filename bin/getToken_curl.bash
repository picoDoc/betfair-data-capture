#! /bin/bash


# Initialise variables, script takes app key and session token as arguments
USERNAME=$1
PASSWORD=$2

function get_session_token() {
 OUT=`curl -s -k --cert $KDBCONFIG/certificates/client-2048.crt --key $KDBCONFIG/certificates/client-2048.key https://identitysso.betfair.com/api/certlogin -d "username=$USERNAME&password=$PASSWORD" -H "X-Application: curlCommandLineTest"`
 echo $OUT
}

get_session_token
