#!/bin/bash -e
./mvnw --batch-mode --settings .maven.xml -Prelease clean install
./deploy.sh --drop-existing
