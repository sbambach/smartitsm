#!/bin/bash


## smartITSM Demo System
## Copyright (C) 2012 synetics GmbH <http://www.smartitsm.org/>
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU Affero General Public License as
## published by the Free Software Foundation, either version 3 of the
## License, or (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU Affero General Public License for more details.
##
## You should have received a copy of the GNU Affero General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.


## i-doit


MODULE="idoit"
TITLE="i-doit pro"
DESCRIPTION="CMDB and IT documentation"
VERSIONS="i-doit pro 1.0 (SVN)"
URL="/i-doit/"
IT_STACK="http://www.smartitsm.org/it_stack/i-doit"
PRIORITY="60"


##
## Default Configuration
##

## Installation directory
if [ -z "${INSTALL_DIR+1}" ]; then
    INSTALL_DIR="/opt/$MODULE"
fi

## Installation directory
if [ -z "${ICINGA_EXPORT_DIR+1}" ]; then
    ICINGA_EXPORT_DIR="${INSTALL_DIR}/icingaexport"
fi


## Installs this module.
function do_install {
    loginfo "Creating destination directory..."
    mkdir -p "$INSTALL_DIR" || return 1
    
    loginfo "Fetching developing version from SVN repository..."
    cd "$INSTALL_DIR" || return 1
    if [ -d ".svn" ]; then
        logdebug "Performing update..."
        svn update || return 1
    else
        logdebug "Performing checkout..."
        svn co http://dev.synetics.de/svn/idoit/branches/idoit-pro . || return 1
    fi

    loginfo "Running setup script..."
    cd "${INSTALL_DIR}/setup"
    {
        echo "idoit_data"
        echo "idoit_system"
        echo "$HOST"
        echo "$MYSQL_DBA_PASSWORD"
        echo "Y"
    } | ./install.sh || return 1
    chown www-data:www-data -R "$INSTALL_DIR" || return 1
    
    loginfo "Patching configuration file..."
    cp "${INSTALL_DIR}/src/config.inc.php" "${INSTALL_DIR}/src/config.inc.php.bak" || return 1
    sed \
        # fix web root:
        -e "s/\"www_dir\"       => \"/\",/\"www_dir\"       => \"/$MODULE\",/g" \
        # increase session timer:
        -e "s/\"sess_time\"     => 600,/\"sess_time\"     => 86400,/g" \
        # enable admin center:
        -e "s/\"admin\" => \"\",/\"admin\" => \"admin\",/g" \
        # TODO configure SMTP
        #-e "s/\"smtp-host\"  => \"\",/\"smtp-host\"  => \"\",/g" \
        "${INSTALL_DIR}/src/config.inc.php.bak" > \
        "${INSTALL_DIR}/src/config.inc.php" || return 1
    
    loginfo "Patching version..."
    cp "${INSTALL_DIR}/src/globals.inc.php" "${INSTALL_DIR}/src/globals.inc.php.bak" || return 1
    sed \
        -e "s/\"version\" => \"0.9.9-9a\",/\"version\" => \"0.9.9-9\",/g" \
        "${INSTALL_DIR}/src/globals.inc.php.bak" > \
        "${INSTALL_DIR}/src/globals.inc.php" || return 1

    loginfo "Installing Apache httpd configuration..."
    cp "${ETC_DIR}/${MODULE}.conf" /etc/apache2/conf.d/ || return 1
    service apache2 reload || return 1
    
    loginfo "Installing license..."
    # TODO fetch and install license file,
    logwarning "Open Web GUI with a browser and install a license. [ENTER]"
    read userinteraction

    loginfo "Performing update..."
    ./controller -v -i 1 -u admin -p admin -m autoup -n v1.0 || return 1

    cd "$BASE_DIR" || return 1
    
    if [ -d "/etc/icinga" ]; then
        loginfo "Configuring i-doit's Nagios module..."
        # TODO configure i-doit's Nagios module, add icinga user (with group Admin)
        logwarning "Open Web GUI with a browser and configure i-doit's Nagios module as described in documentaion. [ENTER]"
        read userinteraction

        logdebug "Creating symbolic links of Icinga export files..."
        mkdir -p "$ICINGA_EXPORT_DIR" || return 1
        chown www-data:www-data -R "$ICINGA_EXPORT_DIR" || return 1
        "$INSTALL_DIR"/controller -m nagios_export -u icinga -p icinga -i 1 -v -n demo.smartitsm.org || return 1
        ln -s "$INSTALL_DIR"/icingaexport/objects/commands.cfg /etc/icinga/objects/i-doit_commands.cfg || return 1
        ln -s "$INSTALL_DIR"/icingaexport/objects/contacts.cfg /etc/icinga/objects/i-doit_contacts.cfg || return 1
        ln -s "$INSTALL_DIR"/icingaexport/objects/hostdependencies.cfg /etc/icinga/objects/i-doit_hostdependencies.cfg || return 1
        ln -s "$INSTALL_DIR"/icingaexport/objects/hostescalations.cfg /etc/icinga/objects/i-doit_hostescalations.cfg || return 1
        ln -s "$INSTALL_DIR"/icingaexport/objects/hostgroups.cfg /etc/icinga/objects/i-doit_hostgroups.cfg || return 1
        ln -s "$INSTALL_DIR"/icingaexport/objects/hosts.cfg /etc/icinga/objects/i-doit_hosts.cfg || return 1
        ln -s "$INSTALL_DIR"/icingaexport/objects/servicedependencies.cfg /etc/icinga/objects/i-doit_servicedependencies.cfg || return 1
        ln -s "$INSTALL_DIR"/icingaexport/objects/serviceescalations.cfg /etc/icinga/objects/i-doit_serviceescalations.cfg || return 1
        ln -s "$INSTALL_DIR"/icingaexport/objects/servicegroups.cfg /etc/icinga/objects/i-doit_servicegroups.cfg || return 1
        ln -s "$INSTALL_DIR"/icingaexport/objects/services.cfg /etc/icinga/objects/i-doit_services.cfg || return 1
        ln -s "$INSTALL_DIR"/icingaexport/objects/timeperiods.cfg /etc/icinga/objects/i-doit_timeperiods.cfg || return 1
        #ln -s "$INSTALL_DIR"/icingaexport/nagios.cfg /etc/icinga/icinga.cfg
        # TODO deploy bin/build_icinga_config_from_i-doit.sh as cron job
        # TODO deploy ""$INSTALL_DIR"/controller -m nagios -u icinga -p icinga -i 1 -v" to write log files
    fi
    
    # TODO configure TTS module
    
    # TODO configure OCS module
    
    # TODO configure ITGS module
    
    # TODO configure LDAP module
    
    do_www_install || return 1

    return 0
}

## Installs homepage configuration.
function do_www_install {
    loginfo "Installing homepage configuration..."
    
    fetchLogo "http://www.smartitsm.org/_media/i-doit/i-doit_logo.png"
    
    loginfo "Installing module configuration..."
    echo "<?php

    \$demos['$MODULE'] = array(
        'title' => '$TITLE',
        'description' => '$DESCRIPTION',
        'url' => '$URL',
        'website' => '$IT_STACK',
        'versions' => '$VERSIONS',
        'credentials' => array(
            'Administrator' => array(
                'username' => 'admin',
                'password' => 'admin'
            )
        )
    );

?>
" > "${WWW_MODULE_DIR}/${PRIORITY}_${MODULE}.php" || return 1
    
    return 0
}

## Upgrades this module.
function do_upgrade {
    lognotice "Not implemented yet. Skipping."
    return 0
}

## Removes this module.
function do_remove {
    lognotice "Not implemented yet. Skipping."
    return 0
}
