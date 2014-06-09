web: bundle exec rackup config.ru -p $PORT
worker: bundle exec sidekiq -r ./app.rb -e production -c 1
