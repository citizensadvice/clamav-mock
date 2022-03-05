FROM ruby:3.1.1-alpine3.15

ENV APP_ROOT /app
WORKDIR $APP_ROOT

COPY . ./

CMD ["ruby", "app.rb"]
