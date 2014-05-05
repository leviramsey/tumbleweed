#!/bin/bash

sudo service mysql start
sudo service mongodb start

hypnotoad uploader.pl
cd tier2
hypnotoad main.pl
cd ..

node app.js

# node will run, so when it stops shut the rest down...

cd tier2
hypnotoad -s main.pl
cd ..
hypnotoad -s uploader.pl
