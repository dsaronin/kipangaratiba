# Set the port to listen on
port 8090

# Set the environment
environment ENV.fetch("RACK_ENV") { "production" }

# Specify the PID file
pidfile '/home/angalia-hub/log/kipangaratiba_puma.pid'

# Load the rackup file (config.ru)
rackup '/home/angalia-hub/projects/kipangaratiba/config.ru'
