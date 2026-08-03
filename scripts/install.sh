ENERGIBRIDGE_VERSION=v0.0.7

wget \
  https://github.com/tdurieux/EnergiBridge/releases/download/v0.0.7/energibridge-v0.0.7-x86_64-unknown-linux-musl.tar.gz
tar -xzf energibridge-v0.0.7-x86_64-unknown-linux-musl.tar.gz

sudo mv energibridge /usr/local/bin/
sudo chmod +x /usr/local/bin/energibridge