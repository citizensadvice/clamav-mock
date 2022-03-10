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
# Run locally
bundle install
CLAMD_TCP_PORT=3310 CLAMD_TCP=localhost ruby app.rb

# Docker
docker build . -t local/clamav-mock
docker run -d -p 3310:3310 local/clamav-mock

# Tests - not included in docker container
bundle exec rspec

# Test using existing instance
START_CLAMD=false CLAMD_TCP_PORT=3310 CLAMD_TCP_HOST=localhost bundle exec rspec

# Test rigs for checking a file against an existing host
cat file | CLAMD_TCP_HOST=localhost CLAMD_TCP_PORT=3310 bundle exec ruby test.rb
```

## TODO

- [x] upgrade ruby version and dependencies
- [ ] rspec shouldn't need app to be started
- [ ] Better instructions in the readme
- [ ] test different line terminations
- [ ] add support for zipped files
- [ ] github action for testing
- [ ] maybe add a test for a python client as well
- [ ] eicar should be entire file
