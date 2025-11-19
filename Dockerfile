FROM ruby:3.4.7-alpine3.22 AS base

ENV APP_ROOT=/app

#################################################

FROM base AS builder

WORKDIR $APP_ROOT
COPY Gemfile* $APP_ROOT

RUN bundle config set --local without 'development' && \
    bundle install && \
    rm -rf /usr/local/bundle/*/*/cache && \
    find /usr/local/bundle -name "*.c" -delete && \
    find /usr/local/bundle -name "*.o" -delete

#################################################

FROM base

COPY --from=builder /usr/local/bundle/ /usr/local/bundle/

# Add user
RUN addgroup ruby -g 3000 && adduser -D -h /home/ruby -u 3000 -G ruby ruby

COPY . $APP_ROOT

WORKDIR $APP_ROOT

RUN rm -rf /app/tmp /app/log \
  && mkdir /app/tmp /app/log \
  && chown -R ruby /app \
  && chmod -R u-w /app \
  && chmod -R u+w /app/tmp /app/log

USER ruby

CMD ["ruby", "app.rb"]
