# Set the port to listen on
port 8090

# Set the environment
environment ENV.fetch("RACK_ENV") { "production" }

# Specify the PID file
pidfile '/home/angalia-hub/log/kipangaratiba_puma.pid'

# Redirect stdout/stderr to log files
# We combine stdout and stderr into one log file for simplicity,
# matching the behavior of your original script.
stdout_redirect '/home/angalia-hub/log/kipangaratiba_puma.log', 
                '/home/angalia-hub/log/kipangaratiba_puma.log', 
                true # append to logs

# Load the rackup file (config.ru)
rackup '/home/angalia-hub/projects/kipangaratiba/config.ru'
