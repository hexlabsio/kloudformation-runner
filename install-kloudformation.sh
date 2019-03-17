#!/bin/bash +e

mkdir -p /usr/local/bin/kloudformation-install
curl -s https://install.kloudformation.hexlabs.io/kloudformation.sh -o /usr/local/bin/kloudformation-install/kloudformation.sh
ln -F -s /usr/local/bin/kloudformation-install/kloudformation.sh /usr/local/bin/kloudformation
chmod +x /usr/local/bin/kloudformation

echo "KloudFormation installed to /usr/local/bin/kloudformation"

kloudformation help