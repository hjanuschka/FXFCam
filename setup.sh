#!/bin/bash
export BUNDLE_PATH=~/.gems
apt-get install libgphoto2-dev build-essential gem ruby
gem install bundler
bundle install
echo "DONE"
