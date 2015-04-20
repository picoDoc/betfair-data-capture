#! /bin/bash


# Initialise variables, script takes app key and session token as arguments
APP_KEY=$1
SESSION_TOKEN=$2
MARKET_ID=$3

HOST=https://api.betfair.com/exchange/betting
PORT=443

# List meta data for chosen market
function list_market_metadata() {
 # number of results returned, can be increased
 local MAX_RESULTS=1
 #OUT=`curl -s -X POST --header "Accept: application/json" --header "Content-Type: application/json" --header "X-Application: $APP_KEY" --header "X-Authentication:   $SESSION_TOKEN"  --data "{\"filter\":{\"marketIds\":[$MARKET_ID]},\"sort\":\"FIRST_TO_START\",\"maxResults\":\"1\",\"marketProjection\":[\"COMPETITION\",\"EVENT\",\"EVENT_TYPE\",\"MARKET_DESCRIPTION\",\"RUNNER_DESCRIPTION\",\"RUNNER_METADATA\"]}" $HOST/rest/v1/listMarketCatalogue/`
 OUT=`wget -qO- --header "Accept: application/json" --header "Content-Type: application/json" --header "X-Application: $APP_KEY" --header "X-Authentication:   $SESSION_TOKEN"  --post-data "{\"filter\":{\"marketIds\":[$MARKET_ID]},\"sort\":\"FIRST_TO_START\",\"maxResults\":\"1\",\"marketProjection\":[\"COMPETITION\",\"EVENT\",\"EVENT_TYPE\",\"RUNNER_DESCRIPTION\",\"RUNNER_METADATA\"]}" $HOST/rest/v1/listMarketCatalogue/`
 echo $OUT
}


# Check if app key and session token are set
if [ "$APP_KEY" == "" ]; then
        read -p "Please provide application key: " APP_KEY
fi
if [ "$SESSION_TOKEN" == "" ]; then
        read -p "Please provide session token: " SESSION_TOKEN
fi

list_market_metadata

