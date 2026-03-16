#!/usr/bin/env bash
set -o errexit

bundle install
npm install
npm run build:css
bundle exec rails assets:precompile
bundle exec rails assets:clean
bundle exec rails db:create || true
bundle exec rails db:migrate
bundle exec rails db:seed
