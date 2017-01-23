```
sudo apt-get -y install git cmake make gcc g++ libaio-dev libncurses5-dev libreadline-dev bison
git clone --depth 1 -b 5.6 https://github.com/percona/percona-server.git
cd percona-server/
git submodule init
git submodule update
cmake . -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_CONFIG=mysql_release -DFEATURE_SET=community -DWITH_EMBEDDED_SERVER=OFF -DIGNORE_AIO_CHECK=ON
make
sudo make install
```