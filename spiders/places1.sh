#!/bin/sh

echo "https://developers.google.com/maps/documentation/places/web-service/place-details"

if [ -z "`env | grep GOOGLE_API_KEY`" ]; then
  echo "please enter GOOGLE_API_KEY, then set it like so:"
  read GOOGLE_API_KEY
  echo "export GOOGLE_API_KEY=$GOOGLE_API_KEY"
  exit
fi

API_KEY=$GOOGLE_API_KEY

#-H 'X-Goog-FieldMask: places.id,places.displayName,places.formattedAddress,places.business_status,places.websiteURI,places.location,places.servesBeer,places.servesCoffee,.places.servesCocktails,' \
#-H 'X-Goog-FieldMask: places.id,places.displayName,places.formattedAddress,places.business_status,places.utc_offset,places.location,places.servesBeer,places.servesCoffee,places.servesCocktails' \
#-H 'X-Goog-FieldMask: *' \
curl -X POST -d '{
  "textQuery" : "Spicy Vegetarian Food in Sydney, Australia"
}' -H 'Content-Type: application/json' -H 'X-Goog-Api-Key: '$API_KEY \
-H 'X-Goog-FieldMask: places.id,places.displayName,places.formattedAddress,places.business_status,places.websiteUri,places.googleMapsLinks,places.utcOffsetMinutes,places.currentOpeningHours,places.currentSecondaryOpeningHours,places.internationalPhoneNumber,places.nationalPhoneNumber,places.regularOpeningHours,places.regularSecondaryOpeningHours,places.location' \
'https://places.googleapis.com/v1/places:searchText'

#-H 'X-Goog-FieldMask: places.id,places.displayName,places.formattedAddress,places.business_status,places.websiteURI,places.location,places.servesBeer,places.servesCoffee,.places.servesCocktails,' 'https://places.googleapis.com/v1/places:searchText'
