FROM ruby:2.6.5-alpine3.10

ENV APP_ROOT /app
WORKDIR $APP_ROOT

COPY . ./

CMD ["ruby", "app.rb"]
