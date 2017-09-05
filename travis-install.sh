#!/usr/bin/env bash
set -ev


if [ $MAGENTO_VERSION == "magento-mirror-1.7.0.2" ]
then
    sudo service mysql stop
    docker run --name mysql -p 3306:3306 -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -d mysql:5.5
fi

#Clean mysql database
mysql -e "DROP DATABASE IF EXISTS magento_test; CREATE DATABASE IF NOT EXISTS magento_test;" -uroot

cd $TRAVIS_BUILD_DIR/build

#1.9.3.0 is currently not in the default version of n98 so add it manually
cat <<EOF > ~/.n98-magerun.yaml
commands:
  N98\Magento\Command\Installer\InstallCommand:
    magento-packages:
      - name: magento-mirror-1.9.3.0
        version: 1.9.3.0
        dist:
          url: https://github.com/OpenMage/magento-mirror/archive/1.9.3.0.zip
          type: zip
        extra:
          sample-data: sample-data-1.9.1.0
EOF


# Install Magento
n98-magerun.phar install --magentoVersion ${MAGENTO_VERSION} --installationFolder "magento" --dbHost "127.0.0.1" --dbUser "root" --dbPass "" --dbName "magento_test" --baseUrl "http://testmagento.local" --forceUseDb --useDefaultConfigParams yes --installSampleData no
mkdir -p magento/var/log

mkdir $TRAVIS_BUILD_DIR/util
cd $TRAVIS_BUILD_DIR/util
#only install test dependencies
composer require satooshi/php-coveralls --no-interaction

#DO NOT USE COMPOSER FOR PHPUNIT as it shares its autoloader
if [ $TRAVIS_PHP_VERSION == "5.5" ]
then
    wget https://phar.phpunit.de/phpunit-4.8.31.phar
    mv phpunit-4.8.31.phar phpunit.phar
else
    wget https://phar.phpunit.de/phpunit-5.7.phar
    mv phpunit-5.7.phar phpunit.phar
fi
chmod +x phpunit.phar

# Install our module
cd $TRAVIS_BUILD_DIR/build/magento
n98-magerun.phar sys:info

modman init
modman link $TRAVIS_BUILD_DIR


if [ $NO_DEPS ]
then
    #create minimal composer json to make sure we can install inchoo php7
    echo 'Install with no deps';
    echo '{"name": "ecocode/magento_profiler", "extra": {"magento-root-dir": "magento/"}}' > ./composer.json
else
    echo 'Install composer deps';
    cp $TRAVIS_BUILD_DIR/composer.json .

    #add magento-root-dir directive
    sed -i 's/"require":/"extra": {"magento-root-dir": "magento\/"},\n    "require":/' composer.json

    composer install --no-dev --no-interaction
fi

if [ $TRAVIS_PHP_VERSION == "7.0" ]
then
    #make php7 possible
    composer config repositories.firegento composer https://packages.firegento.com

    if [ $MAGENTO_VERSION == "magento-mirror-1.9.3.0" ]
    then
        composer require inchoo/php7 2.1.1
    else
        composer require inchoo/php7 1.1.0
    fi
fi

