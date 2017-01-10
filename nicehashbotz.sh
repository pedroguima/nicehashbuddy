#!/bin/bash

#### Variables ################################################

algo=24 		# equihash
apikey=""
apiid=
location=0		# 0 Europe - 1 US
min_workers=2		# How many workers is too low
type=0 			# 0 standard - you don't need a bot for fixed 

###############################################################

WGET="wget -O- -o /dev/null"

## balance_url="https://www.nicehash.com/api?method=balance&id=$apiid&key=$apikey"
orders_url="https://www.nicehash.com/api?method=orders.get&location=$location&algo=$algo"
myorders_url="https://www.nicehash.com/api?method=orders.get&my&id=$apiid&key=$apikey&location=$location&algo=$algo"

# balance=$($WGET $balance_url  | jq -r '.result.balance_confirmed' )
orders=$($WGET $orders_url)
myorderjson=$($WGET $myorders_url)

if [ ! $myorderjson ]; then
	exit 1 
fi

myorderid=$(echo $myorderjson | jq -r '.result.orders[].id')
myorderprice=$(echo $myorderjson | jq -r '.result.orders[].price')
myorderworkers=$(echo $myorderjson | jq -r '.result.orders[].workers')
pricedecrease_url="https://www.nicehash.com/api?method=orders.set.price.decrease&id=$apiid&key=$apikey&location=$location&algo=$algo&order=$myorderid"


echo "##################################################"
echo "$(date)"

### Not the cheapest but the one before the cheapest to allow some margin
optimal_price=$(echo $orders | jq -r '.result.orders'   | jq 'map(select(.workers >5))' | jq 'map(select(.type==0))'  | jq 'map(select(.accepted_speed >0))' | jq -r '.[].price'  | sort -n | uniq | head -n 2 | tail -n 1)

isgreater=$(echo "$myorderprice > $optimal_price" | bc -l)

if [ $isgreater -eq 1 ]; then
	echo "Sir, you need to decrease your bid..!"	
	$WGET $pricedecrease_url | jq -r '.result'
elif [ $myorderprice == $optimal_price ]; then
	if [ $myorderworkers -gt $min_workers ]; then
		echo "Let's push our luck and decrease the price as we have $myorderworkers workers"
		$WGET $pricedecrease_url | jq -r '.result'
	else
		echo "All good, doin' nothing"
	fi
else
	echo "Sir, you need to increase your bid!"
	if [ $myorderworkers -lt $min_workers ]; then
		priceincrease_url="https://www.nicehash.com/api?method=orders.set.price&id=$apiid&key=$apikey&location=0&algo=$algo&order=$myorderid&price=$optimal_price"
		$WGET $priceincrease_url | jq -r '.result'
	else
		echo "Let's push our luck and decrease the price as we have $myorderworkers workers"
		$WGET $pricedecrease_url | jq -r '.result'
	fi
fi


echo "Order id: $myorderid"
echo "Current price (BTC): $myorderprice"
echo "Optimal price (BTC): $optimal_price"
echo ""
echo "##################################################"


