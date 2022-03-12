# Clamav mock

Simple mock for Clamav.  Provides a lightweight docker image that mocks Clamav responses for the instream command.

This acts as a drop-in replacement for [docker clamav/clamav](https://hub.docker.com/r/clamav/clamav) when used with, for example, the [Ruby gem clamav-client](https://rubygems.org/gems/clamav-client).

The mock will respond to PING, INSTREAM and supports IDSESSION only.

The mock will return an OK response for all files, except [eicar virus signature](https://www.eicar.org/?page_id=3950).

Eicar signatures packaged into more exotic file types or in a file over 100kb will not be identified. This is just a mock.

# Running

`docker run -p 3310:3310 public.ecr.aws/citizensadvice/clamav-mock`

Use `CLAMD_TCP_PORT` to customise the port.

# Build and test

```bash
# Run locally
bundle install
CLAMD_TCP_PORT=3310 CLAMD_TCP=localhost bundle exec ruby app.rb

# Docker
docker build . -t local/clamav-mock
docker run -p 3310:3310 local/clamav-mock

# Test - will start and stop the mock on a free port
bundle exec rspec

# Test - test against an existing instance
START_CLAMD=false CLAMD_TCP_PORT=3310 CLAMD_TCP_HOST=localhost bundle exec rspec

# Start locally - use CLAMD_TCP_PORT to change the port.  Defaults to 3310
bundle exec app

# Start the real clamav using docker
docker run -p 3310:3310 clamav/clamav

# Test rig for checking a file against an existing running instance of clamav
cat file | CLAMD_TCP_HOST=localhost CLAMD_TCP_PORT=3310 bundle exec ruby test.rb
```
