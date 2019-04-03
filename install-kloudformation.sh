#!/bin/bash -e

if [[ "$1" == "-local" ]]; then
    curl -s https://install.kloudformation.hexlabs.io/kloudformation.sh -o kloudformation.sh
    chmod +x kloudformation.sh
    echo "KloudFormation installed to ${pwd}/kloudformation.sh"

    echo Installed Version now at `./kloudformation.sh version`
    ./kloudformation.sh help
else
    mkdir -p /usr/local/bin/kloudformation-install
    curl -s https://install.kloudformation.hexlabs.io/kloudformation.sh -o /usr/local/bin/kloudformation-install/kloudformation.sh
    ln -F -s /usr/local/bin/kloudformation-install/kloudformation.sh /usr/local/bin/kloudformation
    chmod +x /usr/local/bin/kloudformation

    echo "KloudFormation installed to /usr/local/bin/kloudformation"

    echo Installed Version now at `kloudforamtion version`
    kloudformation help
fi

