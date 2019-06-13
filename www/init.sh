#!/usr/bin/env bash

HOME=`pwd`

mvn clean install -f $HOME/pom.xml
java -jar $HOME/target/ballerina-integrator-site-builder-1.0-SNAPSHOT-jar-with-dependencies.jar
cd $HOME/www-site
jekyll serve
