#!/bin/sh

# A MediaWiki Gerrit browser test bot 
#
# Installs the following:
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

	#generate ssh key
	echo "Please enter a path for your new public key: (default is /home/$username/.ssh/id_rsa)"
	read pubkeypath
	pubkeypath="${pubkeypath:=/home/$username/.ssh/id_rsa}"
	su -c "ssh-keygen -f $pubkeypath" -m $username
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
	cd /usr/local/bin && \
		git clone https://github.com/phacility/arcanist.git
	cd /usr/local/bin/arcanist/externals/includes/ && \
		git clone https://github.com/phacility/libphutil.git
	# Add Arcanist bin to the path
	echo "PATH=\"/usr/local/bin/arcanist/bin:\$PATH\"" >> /home/$username/.bashrc
fi

# Reload .bashrc
source /home/$username/.bashrc

# Phabricator
echo "Goto https://phabricator.wikimedia.org/conduit/login/ \ n
	to get an API key and copy it to the clipboard"
read phabricatorApiKey

#configure arc
su -c "arc --conduit-uri=https://phabricator.wikimedia.org install-certificate" -m $username

echo "Be sure to add your public key to gerrit \
 https://gerrit.wikimedia.org/r/#/settings/ssh-keys"
echo "Paste your public key:"
cat "$pubkeypath.pub"
