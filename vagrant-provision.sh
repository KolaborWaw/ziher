#!/bin/bash

set -ex

echo ====================== Przygowotuje maszyne...
# Add environment variables to bash.bashrc if not already there
if ! grep -q 'export LANGUAGE=en_US.UTF-8' /etc/bash.bashrc; then
  sudo -H -u vagrant -i echo "export LANGUAGE=en_US.UTF-8" >> /etc/bash.bashrc
fi

if ! grep -q 'export LANG=en_US.UTF-8' /etc/bash.bashrc; then
  sudo -H -u vagrant -i echo "export LANG=en_US.UTF-8" >> /etc/bash.bashrc
fi

if ! grep -q 'export LC_ALL=en_US.UTF-8' /etc/bash.bashrc; then
  sudo -H -u vagrant -i echo "export LC_ALL=en_US.UTF-8" >> /etc/bash.bashrc
fi

locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
update-locale LC_ALL=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

export DEBIAN_FRONTEND=noninteractive
apt-get update

# install docker
apt-get install --yes \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install --yes \
  docker-ce \
  docker-ce-cli \
  containerd.io

usermod -aG docker vagrant

#echo ====================== Instaluje rbenv
apt-get install --yes git curl vim libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-dev

# Check if rbenv directory exists before cloning
if [ ! -d "/home/vagrant/.rbenv" ]; then
  sudo -H -u vagrant -i bash -c "git clone https://github.com/rbenv/rbenv.git /home/vagrant/.rbenv"
else
  echo "rbenv directory already exists, skipping clone"
fi

# Check if ruby-build directory exists before cloning
if [ ! -d "/home/vagrant/.rbenv/plugins/ruby-build" ]; then
  sudo -H -u vagrant -i bash -c "git clone https://github.com/rbenv/ruby-build.git /home/vagrant/.rbenv/plugins/ruby-build"
else
  echo "ruby-build directory already exists, skipping clone"
fi

# Add rbenv to PATH in bash_profile if not already there
if ! sudo -H -u vagrant -i grep -q 'export PATH="$HOME/.rbenv/bin:$PATH"' /home/vagrant/.bash_profile; then
  sudo -H -u vagrant -i echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> /home/vagrant/.bash_profile
fi

# Add rbenv init to bash_profile if not already there
if ! sudo -H -u vagrant -i grep -q 'eval "$(rbenv init -)"' /home/vagrant/.bash_profile; then
  sudo -H -u vagrant -i echo 'eval "$(rbenv init -)"' >> /home/vagrant/.bash_profile
fi

# Check if Ruby is already installed with correct version
if ! sudo -H -u vagrant -i bash -c "/home/vagrant/.rbenv/bin/rbenv versions | grep -q 2.6.10"; then
  sudo -H -u vagrant -i bash -c "/home/vagrant/.rbenv/bin/rbenv install 2.6.10"
  sudo -H -u vagrant -i bash -c "/home/vagrant/.rbenv/bin/rbenv global 2.6.10"
else
  echo "Ruby 2.6.10 is already installed, skipping installation"
fi

# Add color prompt if not already there
if ! sudo -H -u vagrant -i grep -q 'force_color_prompt=yes' /home/vagrant/.bashrc; then
  sudo -H -u vagrant -i echo "force_color_prompt=yes" >> /home/vagrant/.bashrc
fi

# https://github.com/mitchellh/vagrant/issues/866 - ~/.bashrc is not loaded in 'vagrant ssh' sessions
if ! sudo -H -u vagrant -i grep -q 'source ~/.bashrc' /home/vagrant/.bash_profile; then
  sudo -H -u vagrant -i echo "source ~/.bashrc" >> /home/vagrant/.bash_profile
fi

if ! sudo -H -u vagrant -i grep -q 'cd /ziher' /home/vagrant/.bash_profile; then
  sudo -H -u vagrant -i echo "cd /ziher" >> /home/vagrant/.bash_profile
fi

echo ====================== Instaluje PostgreSQL
docker compose -f /ziher/docker/docker-compose.yml up -d postgres
apt-get install --yes libpq-dev

# Create PostgreSQL role only if it doesn't exist
if ! docker exec -u postgres postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='ziher'" | grep -q 1; then
  docker exec -u postgres postgres bash -c "psql postgres -c \"create role ziher with CREATEDB SUPERUSER login password 'ziher'\""
else
  echo "PostgreSQL role 'ziher' already exists, skipping creation"
fi

# Configure git only if not already configured
if ! sudo -H -u vagrant -i bash -c "git config --get color.ui"; then
  sudo -H -u vagrant -i bash -c "git config --global color.ui true"
fi

echo ====================== Sciagam gemy i uzupelniam baze danych
apt-get install --yes g++
# pakiety potrzebne dla wkhtmltopdf
apt-get install --yes libfontconfig1 libxrender1 libjpeg-turbo8
sudo -H -u vagrant -i bash -c "gem install bundler -v 2.3.26"
sudo -H -u vagrant -i bash -c "bundler config --local clean false"
sudo -H -u vagrant -i bash -c "cd /ziher; bundle install"

# Check if database exists before trying to create it
if ! sudo -H -u vagrant -i bash -c "cd /ziher; rails runner 'ActiveRecord::Base.connection'" 2>/dev/null; then
  sudo -H -u vagrant -i bash -c "cd /ziher; rake db:create"
  sudo -H -u vagrant -i bash -c "cd /ziher; rake db:setup"
else
  echo "Database already exists, skipping db:create and db:setup"
fi

set +x
echo '====================== ZiHeR jest gotowy do zabawy!'
echo '====================== Aby zalogowac sie na maszyne wpisz'
echo '====================== $ vagrant ssh <enter>'
echo '======================'
echo '====================== Nastepnie wejdz do katalogu z ZiHeRem'
echo '====================== $ cd /ziher <enter>'
echo '======================'
echo '====================== Po czym odpal serwer http ktory poda Ci ZiHeRa na tacy'
echo '====================== $ rails server -b 0.0.0.0 <enter>'
echo '======================'
echo '====================== Po wykonaniu tych komend twoj wlasny i niepowtarzalny ZiHeR czeka na Ciebie :]'
echo '====================== W przegladarce wpisz: http://192.168.56.1:3000'
echo '====================== (uzytkownik: admin@ziher, haslo: admin@ziher)'
