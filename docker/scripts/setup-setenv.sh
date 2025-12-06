#!/bin/bash
# Setup setenv file if it doesn't exist
# This script is used by Docker services to configure the setenv file

if [ ! -f setenv ]; then
    echo 'Creating setenv from setenv.default...'
    cp setenv.default setenv
    sed -i 's|MDE4CPP_HOME=$PWD|MDE4CPP_HOME=/home/mde4cpp|' setenv
    sed -i 's|MDE4CPP_ECLIPSE_HOME=~.*|MDE4CPP_ECLIPSE_HOME=/home/mde4cpp/eclipse|' setenv
    sed -i 's|ORG_GRADLE_PROJECT_WORKER=1|ORG_GRADLE_PROJECT_WORKER=3|' setenv
    sed -i '/cd \.\/gradlePlugins/,/cd $MDE4CPP_HOME/d' setenv
    sed -i '/^# bash$/d; /^bash$/d' setenv
    chmod +x setenv
    echo '✓ setenv created and configured'
else
    echo '✓ setenv already exists, ensuring it is properly configured...'
    # Always ensure gradlew commands are removed (they execute when sourcing)
    sed -i '/cd \.\/gradlePlugins/,/cd $MDE4CPP_HOME/d' setenv
    sed -i '/^# bash$/d; /^bash$/d' setenv
    # Update paths if they're still using old values
    sed -i 's|MDE4CPP_HOME=$PWD|MDE4CPP_HOME=/home/mde4cpp|' setenv
    sed -i 's|MDE4CPP_ECLIPSE_HOME=~.*|MDE4CPP_ECLIPSE_HOME=/home/mde4cpp/eclipse|' setenv
    sed -i 's|ORG_GRADLE_PROJECT_WORKER=1|ORG_GRADLE_PROJECT_WORKER=3|' setenv
    echo '✓ setenv updated and configured'
fi
