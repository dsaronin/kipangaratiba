# ~/projectspace/kipangaratiba/sidekiq_boot.rb

# This file is loaded by 'bundle exec sidekiq -r ./sidekiq_boot.rb'
# It loads *only* the bare minimum the Sidekiq server needs.

# require 'pathname'
# APP_ROOT = Pathname.new(File.expand_path('.', __dir__))

# Load the environment for logging
require_relative './app/environ'

# Load the scheduler (for its Redis config) and worker
require_relative './app/kipanga_scheduler'
require_relative './app/shell_worker'

# Initialize the scheduler singleton to configure Sidekiq's Redis connection.
Kipangaratiba::KipangaScheduler.instance

# 4. Log that the Sidekiq server process is booting
Kipangaratiba::Environ.log_info("Sidekiq Boot: Sidekiq server process starting...")
Kipangaratiba::Environ.log_info("Sidekiq Boot: Redis configured and ShellWorker loaded.")

