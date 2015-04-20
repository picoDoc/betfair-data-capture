#! /bin/bash


# Initialise variables, script takes app key and session token as arguments
APP_KEY=$1
SESSION_TOKEN=$2
MARKET_ID=$3

HOST=https://api.betfair.com/exchange/betting
PORT=443

# List market data for chosen market
function list_market_data() {
 # number of results returned, can be increased
 local MAX_RESULTS=1
 #OUT=`curl -s -X POST --header "Accept: application/json" --header "Content-Type: application/json" --header "X-Application: $APP_KEY" --header "X-Authentication: $SESSION_TOKEN"  --data "{\"marketIds\":[\"$MARKET_ID\"],\"priceProjection\":{\"priceData\":[\"EX_BEST_OFFERS\"],\"exBestOfferOverRides\":{\"bestPricesDepth\":2,\"rollupModel\":\"STAKE\",\"rollupLimit\":20},\"virtualise\":false,\"rolloverStakes\":false},\"orderProjection\":\"ALL\",\"matchProjection\":\"ROLLED_UP_BY_PRICE\"}" $HOST/rest/v1/listMarketBook/`
 OUT=`wget -qO- --header "Accept: application/json" --header "Content-Type: application/json" --header "X-Application: $APP_KEY" --header "X-Authentication: $SESSION_TOKEN"  --post-data "{\"marketIds\":[\"$MARKET_ID\"],\"priceProjection\":{\"priceData\":[\"EX_ALL_OFFERS\",\"EX_TRADED\"],\"virtualise\":false,\"rolloverStakes\":false},\"orderProjection\":\"ALL\",\"matchProjection\":\"ROLLED_UP_BY_PRICE\"}" $HOST/rest/v1/listMarketBook/`
 echo $OUT
}


# Check if app key and session token are set
if [ "$APP_KEY" == "" ]; then
        read -p "Please provide application key: " APP_KEY
fi
if [ "$SESSION_TOKEN" == "" ]; then
        read -p "Please provide session token: " SESSION_TOKEN
fi

list_market_data

