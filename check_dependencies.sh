#!/usr/bin/env bash

COUCHDB=$(command -v couchdb);

NVM_DIR=~/.nvm;

[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh";

NVM=$(command -v nvm);

NODE=$(command -v node);

if [ ${#COUCHDB} == 0 ]; then

    echo "Need to install CouchDB...";

    echo "Installing CouchDB...";

    sudo apt-get install software-properties-common -y;

    sudo add-apt-repository ppa:couchdb/stable -y;

    sudo apt-get update;

    sudo apt-get remove couchdb couchdb-bin couchdb-common -yf;

    sudo apt-get autoremove -yf;

    sudo apt-get install couchdb -y;

    clear

    read -p "Enter CouchDB database usename: " COUCHDB_DATABASE_USERNAME

    echo -n "Enter CouchDB database password for '$COUCHDB_DATABASE_USERNAME': "

    read -s COUCHDB_DATABASE_PASSWORD

    curl -X PUT -H 'Content-Type: application/json' --data '"' + $COUCHDB_DATABASE_PASSWORD + '"' "http://localhost:5984/_config/admins/$COUCHDB_DATABASE_USERNAME"

    sudo sed -i 's/;port = 5984/port = 5984/g' /etc/couchdb/local.ini

    sudo sed -i 's/;bind_address = 127.0.0.1/bind_address = 0.0.0.0/g' /etc/couchdb/local.ini

    sudo service couchdb restart

    curl localhost:5984

    echo

    echo "NOTE: Please make sure you add an admin account in CouchDB for use later in the migration process."

    echo

else

    echo "CouchDB found: OK";

fi

if [ ${#NVM} == 0 ]; then

    echo "NVM not found...";

    echo "Installing NVM...";

    sudo apt-get remove --purge node -y;

    sudo apt-get install build-essential checkinstall -y;

    sudo apt-get install libssl-dev -y;

    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.0/install.sh | bash;

    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh";

else

    echo "NVM found: OK";

fi

if [ ${#NODE} == 0 ]; then

    echo "Node.js not found...";

    echo "Installing Node.js";

    nvm install 5.10.1;

    nvm use 5.10.1;

    nvm alias default node;

else

    echo "Node.js found: OK";

fi

npm install --save --verbose;