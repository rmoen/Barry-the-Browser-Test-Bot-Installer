#!/bin/sh

# install.js - Install Barry and friends
#
# Installs
# nodejs, npm, Phantomjs, ruby, ruby-dev, bundler, arcanist,
# 	git-review barrybot a bunch of stuff
#
# Creates and configures a user account to run the browser tests
# Configuration: Username, BROWSER, MEDIAWIKI_URL, MEDIAWIKI_API_URL,
#	MEDIAWIKI_USER, MEDIAWIKI_PASSWORD, 

# Install npm if not installed
command -v npm >/dev/null 2>&1 || {
	echo "Installing npm."
	apt-get install npm
}

# Install legacy node for phantomjs
#  It expects node to be a command
sudo apt-get install nodejs-legacy

# Install phantom js if not installed
if test -e /usr/local/bin/phantomjs; then
	echo "Phantomjs found"
else
	echo "Installing phantomjs"
	npm install -g phantomjs
fi

# Install ruby and ruby-dev
apt-get install ruby ruby-dev
# update rubgems
gem update --system

# Install bundler gem if not installed
if test -e /usr/local/bin/bundler; then
	echo "Bundler found"
else
	echo "Installing bundler"
	gem install bundler
fi

# Install git-review if not installed
if test -e /usr/local/bin/git-review; then
	echo "git-review found"
else
	echo "Installing git-review"
	apt-get install git-review
fi

echo "Please enter the gerrit account name (eg: barrybrowsertestbot)"
read gerritUsername

# Set the git username to the gerrit account
su -c "git config --global user.name $gerritUsername" -m $username

echo "Please enter a username for the bot on the system.   Has to be different name than the bot's gerrit username."
read username
echo "Looking for user $username"

# Check for user $username on the system 

if test -e /home/$username; then
	echo "User $username already exists."
else
	echo "Creating $username user."
	#add user
	adduser --ingroup wikidev $username
	cd /home/$username && git clone https://github.com/jdlrobson/Barry-the-Browser-Test-Bot.git barrybot
	# Add barrybot to the path
	echo "PATH=\"/home/$username/barrybot:\$PATH\"" >> /home/$username/.bashrc

	# Generate ssh key
	echo "Generating new ssh key..."
	pubkeypath="/home/$username/.ssh/id_rsa"
	su -c "ssh-keygen -f $pubkeypath" -m $username

	# setup the variables needed by the browser tests
	echo "Please enter mediawiki server url (default: http://reading-smoketest.wmflabs.org)"
	read MW_SERVER
	MW_SERVER="${MW_SERVER:=http://reading-smoketest.wmflabs.org}"

	MW_SCRIPT_PATH="/w"
	MEDIAWIKI_URL="$MW_SERVER/wiki/"
	MEDIAWIKI_API_URL="$MW_SERVER$MW_SCRIPT_PATH/api.php"
	MEDIAWIKI_LOAD_URL="$MW_SERVER$MW_SCRIPT_PATH/load.php"
	BROWSER="phantomjs"

	# Create a Mediawiki user account for testing via the api
	cookiesFile="cookies.txt"
	MEDIAWIKI_USER="Mr_Selenium"
	# Random 10 character password
	MEDIAWIKI_PASSWORD=`openssl rand -base64 10`

	# add variables to .bashrc
	echo "export MEDIAWIKI_ENVIRONMENT=barry" >> /home/$username/.bashrc
	echo "export MW_SERVER=$MW_SERVER" >> /home/$username/.bashrc
	echo "export MW_SCRIPT_PATH=$MW_SCRIPT_PATH" >> /home/$username/.bashrc
	echo "export MEDIAWIKI_URL=$MEDIAWIKI_URL" >> /home/$username/.bashrc
	echo "export MEDIAWIKI_USER=$MEDIAWIKI_USER" >> /home/$username/.bashrc
	echo "export MEDIAWIKI_PASSWORD=$MEDIAWIKI_PASSWORD" >> /home/$username/.bashrc
	echo "export MEDIAWIKI_API_URL=$MEDIAWIKI_API_URL" >> /home/$username/.bashrc
	echo "export MEDIAWIKI_LOAD_URL=$MEDIAWIKI_LOAD_URL" >> /home/$username/.bashrc
	echo "export BROWSER=$BROWSER" >> /home/$username/.bashrc
fi

# Install and configure arcanist if not installed
if test -e /usr/local/bin/arcanist/; then
	echo "Arcanist found"
else
	echo "Installing Arcanist"
	# be sure php5-curl is installed
	sudo apt-get install php5-curl
	cd /usr/local/bin && \
		git clone https://github.com/phacility/arcanist.git
	cd /usr/local/bin/arcanist/externals/includes/ && \
		git clone https://github.com/phacility/libphutil.git
	# Add Arcanist bin to the path
	echo "PATH=\"/usr/local/bin/arcanist/bin:\$PATH\"" >> /home/$username/.bashrc
fi

# Configure arc
su $username -c "/usr/local/bin/arcanist/bin/arc  \
	--conduit-uri=https://phabricator.wikimedia.org install-certificate"
echo "\n"
# Gather list of projects you care about and write script to start and stop bot....

echo "\n"
echo "Add your new public key to gerrit at: \
 https://gerrit.wikimedia.org/r/#/settings/ssh-keys"
echo "\n"
cat "$pubkeypath.pub"

# Default mediawiki path
mediawikiPath="/vagrant/mediawiki"

# Create and promote Mr_Selenium
php $mediawikiPath/maintenance/createAndPromote.php "$MEDIAWIKI_USER" "$MEDIAWIKI_PASSWORD" --bureaucrat --force --sysop

# Required for browser tests ui_links.feature
echo '$wgRightsText = "Creative Commons Attribution 3.0";' >> $mediawikiPath/LocalSettings.php
echo '$wgRightsUrl = "http://creativecommons.org/licenses/by-sa/3.0/";' >> $mediawikiPath/LocalSettings.php
echo '$wgPasswordAttemptThrottle = false;' >> $mediawikiPath/LocalSettings.php

# Let's configure a run script.  Assume it is one project for the moment.
echo "Please enter a project name (example: Gather)"
read projectName
projectName="${projectName:=Gather}"
projectPath="$mediawikiPath/extensions/$projectName/"
# Hack: Run bundle install as the original user
su -c "cd $projectPath && bundle install" -m $USER

# Setup a Spanish Interwiki link using sql
cd "${BASH_SOURCE%/*}" && mysql -u root -pvagrant < interwiki.sql

echo "Please enter the name of the extension this project depends on (optional. example: MobileFrontend)"
read dependencyString
dependencyString="${dependencyString:+--dependencies $mediawikiPath/extensions/$dependencyString}"

echo "Please enter a test tag (optional. example: smoke)"
read tagString
# If tag is set, replace with --tag tagString
tagString="${tagString:+--tag $tagString}"

runScriptPath=/home/$username/barrybot/run.sh
cat << EOF > $runScriptPath
	#!/bin/sh
	while :
	do
		# Do Gather - trigger a review on the result. --project corresponds to the Gerrit project you want to test.
		# --core, --test --dependencies correspond to absolute directories on your machine. --core and --dependencies will be switched to master and updated before launching the browser tests.
		./barrybot.py --user $gerritUsername --review 1 --paste 1 --project mediawiki/extensions/$projectName --core $mediawikiPath --test $projectPath $dependencyString $tagString
		# sleep for 30 minutes
		sleep 1800
	done
EOF

# make the script executable
chmod +x $runScriptPath

# Make it so wikidev can modify vagrant
chmod -R g+w $mediawikiPath

# Change permissions on the barrybot dir
chown -R $username:wikidev /home/$username/barrybot

# Setup git-review
su -c "cd $mediawikiPath && git-review" -m $username

echo "Just created $runScriptPath, please make any modifications needed."
