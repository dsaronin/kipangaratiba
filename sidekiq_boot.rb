# ~/projectspace/kipangaratiba/sidekiq_boot.rb

# This file is loaded by 'bundle exec sidekiq -r ./sidekiq_boot.rb'
# It loads *only* what the Sidekiq server process needs.

# 1. Set the current directory for relative paths
require 'pathname'
require_relative './app/kipangaratiba_work'  # core application logic, initializes Environ
require_relative './app/shell_worker'  # the worker definition

APP_ROOT = Pathname.new(File.expand_path('.', __dir__))


# Initialize the application; similar logic from config.ru.
# This creates KipangaScheduler, which configures Redis for Sidekiq.
#
KIPANGARATIBA = Kipangaratiba::KipangaratibaWork.new
KIPANGARATIBA.setup_work() 

Kipangaratiba::Environ.log_info("Sidekiq Boot: Sidekiq server process starting...")
Kipangaratiba::Environ.log_info("Sidekiq Boot: Redis configured and ShellWorker loaded.")
