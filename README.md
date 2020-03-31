# Clamav mock

Simple mock for Clamav.  Provides a super lightweight docker image that mocks
Clamav responses for the instream command.

The mock will respond to PING, INSTREAM and supports IDSESSION only.

The mock will identify the [eicar virus signature](https://www.eicar.org/?page_id=3950) within any file, but not within a zip or other compressed or modified file structure.

# Running

`docker run -p 3310:3310 citizensadvice/clamav-mock`

Use `CLAMD_TCP_PORT` to customise the port.

# Build and test

```bash
# Docker
docker build . -t local/clamav-mock
docker run -d -p 3310:3310 local/clamav-mock

# Or start locally
CLAMD_TCP_PORT=3310 ruby app.rb

# Install locally
bundle install

# rspec - run locally only, not included in the container
CLAMD_TCP_HOST=localhost CLAMD_TCP_PORT=3310 bundle exec rspec

# Test a file
cat file | CLAMD_TCP_HOST=localhost CLAMD_TCP_PORT=3310 bundle exec ruby test.rb
```
