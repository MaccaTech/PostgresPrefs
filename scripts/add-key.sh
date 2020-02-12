#!/usr/bin/env sh

# Set the filename
export APPLICATION_CERTIFICATE_P12=application-cert.p12;
export INSTALLER_CERTIFICATE_P12=installer-cert.p12;

# Decode the environment variable into our file
echo $MACOS_CERT_P12_APPLICATION | base64 --decode > $APPLICATION_CERTIFICATE_P12;
echo $MACOS_CERT_P12_INSTALLER | base64 --decode > $INSTALLER_CERTIFICATE_P12;

# Let's invent a new keychain
export KEYCHAIN=build.keychain;

# Create a custom keychain
security create-keychain -p travis $KEYCHAIN;

# Make the custom keychain default, so xcodebuild will use it for signing
security default-keychain -s $KEYCHAIN;

# Unlock the keychain
security unlock-keychain -p travis $KEYCHAIN;

# Add certificates to keychain and allow codesign to access them
security import ./scripts/certs/AppleWWDRCA.cer -k ~/Library/Keychains/$KEYCHAIN -T /usr/bin/codesign;
security import ./scripts/certs/MaccaTechDeveloperIDApplication.cer -k ~/Library/Keychains/$KEYCHAIN -T /usr/bin/codesign;
security import ./scripts/certs/MaccaTechDeveloperIDInstaller.cer -k ~/Library/Keychains/$KEYCHAIN -T /usr/bin/codesign;
security import $APPLICATION_CERTIFICATE_P12 -k $KEYCHAIN -P $MACOS_CERT_PASSWORD -T /usr/bin/codesign 2>&1 >/dev/null;
security import $INSTALLER_CERTIFICATE_P12 -k $KEYCHAIN -P $MACOS_CERT_PASSWORD -T /usr/bin/codesign 2>&1 >/dev/null;

# Let's delete the file, we no longer need it
rm $APPLICATION_CERTIFICATE_P12;
rm $INSTALLER_CERTIFICATE_P12;

# Set the partition list (sort of like an access control list)
security set-key-partition-list -S apple-tool:,apple: -s -k travis $KEYCHAIN;

# Echo the identity, just so that we know it worked.
security find-identity -v -p codesigning;
