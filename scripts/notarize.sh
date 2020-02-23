#!/usr/bin/env bash

DMG_DIR="./build/$POSTGRES_PREFS_NAME"
DMG="$DMG_DIR.dmg"

# Reset
rm -rf "$DMG_DIR"
rm -f "$DMG"

# Code sign
mkdir -p "$DMG_DIR"
cp -R ./build/Build/Products/Release/PostgreSQL.prefPane "$DMG_DIR"
echo
echo "Creating $DMG ..."
hdiutil create -srcfolder "$DMG_DIR" "$DMG"
codesign --sign "Developer ID Application: Macca Tech Ltd" "$DMG"

# Notarize
echo
echo "Notarizing $DMG ..."
response=`xcrun altool --notarize-app --primary-bundle-id "tech.macca.PostgresPrefs" --username "info@maccatech.com" --password "$NOTARIZE_PASSWORD" --file "$DMG"`
echo $response

# Extract UUID
uuid=`echo "$response" | sed -nE 's/RequestUUID[[:space:]]*\=[[:space:]]*([[:alnum:]_]*)/\1/p'`
if [ -z "$uuid" ]; then
	echo "ERROR: RequestUUID not found"
	exit 1
fi

# Poll until finished
interval=20
((start_time=${SECONDS}))
((end_time=${SECONDS}+3600))

while ((${SECONDS} < ${end_time}))
do
  elapsed=`printf '%0.1f\n' $(bc <<<"scale=1; (${SECONDS}-$start_time)/60")`
  echo
  echo "Checking $uuid ($elapsed minutes) ..."
  if response=`xcrun altool -u "info@maccatech.com" -p "$NOTARIZE_PASSWORD" --notarization-info "$uuid"`; then
    statusCode=`echo "$response" | sed -nE 's/.*Status[[:space:]]*Code[[:space:]]*\:[[:space:]]*([[:digit:]]+).*/\1/p'`
    echo "$response" | grep -i "tatus"
    if [ -n "$statusCode" ]; then
      break
    fi
  else
    break
  fi
  sleep ${interval}
done

if [[ statusCode -ne "0" ]]; then
  echo "Notarization failed"
  echo "$response"
  exit 1
fi

# Print out notarization check
echo
echo "Checking $DMG ..."
spctl -a -t install --context context:primary-signature -v "$DMG"
