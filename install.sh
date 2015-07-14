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

echo "Please enter a username for the bot on the system.  Your labs/Gerrit username is recommended."
read username
echo "Looking for user $username"

# Check for user $username on the system 

if test -e /home/$username; then
	echo "User $username already exists."
else
	echo "Creating $username user."
	#add user
	adduser $username --home /home/$username
	mkdir /home/$username/bin

	cd /home/$username/bin && git clone https://github.com/jdlrobson/Barry-the-Browser-Test-Bot.git barrybot
	# Add barrybot bin to the path
	echo "PATH=\"/home/$username/bin/barrybot/bin:\$PATH\"" >> /home/$username/.bashrc

	chown -R $username:$username /home/$username/bin

	# Generate ssh key
	echo "Please enter a path for your new public key: (default is /home/$username/.ssh/id_rsa)"
	read pubkeypath
	pubkeypath="${pubkeypath:=/home/$username/.ssh/id_rsa}"
	su -c "ssh-keygen -f $pubkeypath" -m $username

	# setup the variables needed by the browser tests
	echo "Please enter mediawiki server url (default: http://one.wmflabs.org)"
	read MW_SERVER
	MW_SERVER="${MW_SERVER:=http://one.wmflabs.org}"

	echo "Please enter the MediwaWiki script path (default: /w)"
	read MW_SCRIPT_PATH
	MW_SCRIPT_PATH="${MW_SCRIPT_PATH:=/w}"

	echo "Please enther the mediawiki wiki url (default: $MW_SERVER/wiki/)"
	read MEDIAWIKI_URL
	MEDIAWIKI_URL="${MEDIAWIKI_URL:=$MW_SERVER/wiki/}"

	echo "Please enter the test mediawiki account username (default: Mr_Selenium)"
	read MEDIAWIKI_USER
	MEDIAWIKI_USER="${MEDIAWIKI_USER:=Mr_Selenium}"

	echo "Please enter the test MediaWiki account password (default: passwords"
	read MEDIAWIKI_PASSWORD
	MEDIAWIKI_PASSWORD="${MEDIAWIKI_PASSWORD:=passwords}"

	echo "Please enter the mediawiki api url (default: $MW_SERVER$MW_SCRIPT_PATH/api.php)"
	read MEDIAWIKI_API_URL
	MEDIAWIKI_API_URL="${MEDIAWIKI_API_URL:=$MW_SERVER$MW_SCRIPT_PATH/api.php}"

	echo "Please enter the mediawiki load url (default: $MW_SERVER$MW_SCRIPT_PATH/load.php)"
	read MEDIAWIKI_LOAD_URL
	MEDIAWIKI_LOAD_URL="${MEDIAWIKI_API_URL:=$MW_SERVER$MW_SCRIPT_PATH/load.php}"

	echo "Please enter the mediawiki load url. Use '' for default browser, phantomjs for headless. (default: '')"
	read BROWSER
	BROWSER="${BROWSER:=phantomjs}"

	# add variables to .bashrc
	echo "export MW_SERVER=$MW_SERVER" >> /home/$username/.bashrc
	echo "export MW_SCRIPT_PATH=$MW_SCRIPT_PATH" >> /home/$username/.bashrc
	echo "export MEDIAWIKI_URL=$MEDIAWIKI_URL" >> /home/$username/.bashrc
	echo "export MEDIAWIKI_USER=$MEDIAWIKI_USER" >> /home/$username/.bashrc
	echo "export MEDIAWIKI_PASSWORD=$MEDIAWIKI_PASSWORD" >> /home/$username/.bashrc
	echo "export MEDIAWIKI_API_URL=$MEDIAWIKI_API_URL" >> /home/$username/.bashrc
	echo "export MEDIAWIKI_LOAD_URL=$MEDIAWIKI_LOAD_URL" >> /home/$username/.bashrc
	echo "export BROWSER=$BROWSER" >> /home/$username/.bashrc

fi

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

# Insatll ruby and ruby-dev
apt-get install ruby ruby-dev

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
