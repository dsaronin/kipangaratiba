# --- kipanga_scheduler.rb ---
#
# Kipangaratiba:
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#

require 'singleton'
require_relative 'environ' # Required for Environ.log_info, Environ.my_monitor_default

# --- Additions for Sidekiq ---
require 'sidekiq'
require 'sidekiq-cron'
# -----------------------------


# +++++++++++++++++++++++++++++++++++++++++++++++++
module Kipangaratiba              # Define the top-level module  
# +++++++++++++++++++++++++++++++++++++++++++++++++

class KipangaScheduler
  include Singleton

  def initialize
    setup_sidekiq_config # Configure Redis connection first
    verify_configuration # Perform configuration check on initialization
  end

  # ------------------------------------------------------------
  # verify_configuration -- Checks for critical 
  # Raises KipangaSchedulerError if configuration is incorrect.
  # ------------------------------------------------------------
  def verify_configuration
    Environ.log_info("KipangaScheduler: Verifying configuration.")
    begin
      info = Sidekiq.redis_pool.with { |conn| conn.info }
      Environ.log_info("KipangaScheduler: Redis connection verified. Version: #{info['redis_version']}")
    rescue => e
      Environ.log_error("KipangaScheduler: FAILED to connect to Redis: #{e.message}")
      raise # Re-raise to halt startup
    end
  end # verify_configuration

  # ============================================================
  # --- PUBLIC SCHEDULING INTERFACE ---
  # ============================================================
  # NOTE: all parameters for scheduling follow same format
  # *args [Array] -- Arguments to pass to ShellWorker.perform
  # *args empty: immediate nop (writes to log)
  # args[0]: command-string for system() call
  # ------------------------------------------------------------
  # schedule_job_now  -- queues background job for immediate execution
  # ------------------------------------------------------------
  def self.schedule_job_now(*args)
    Environ.log_info("KipangaScheduler: Scheduling job now: #{args.inspect}")
    ShellWorker.perform_async(*args)
  end

  # ------------------------------------------------------------
  #schedule_job_in  -- schedules background job for execution after a time interval
  # interval [Integer, Float]  -- wait time interval in seconds
  # ------------------------------------------------------------
  def self.schedule_job_in(interval, *args)
    Environ.log_info("KipangaScheduler: Scheduling job after #{interval}-sec: #{args.inspect}")
    ShellWorker.perform_in(interval, *args)
  end

  # ------------------------------------------------------------
  # schedule_job_at  --  schedules background job to run at specific 'time'
  # time [Time] -- specific time at which to run the job
  # ------------------------------------------------------------
  def self.schedule_job_at(time, *args)
    Environ.log_info("KipangaScheduler: Scheduling job for #{time}: #{args.inspect}")
    ShellWorker.perform_at(time, *args)
  end

  # ------------------------------------------------------------
  # schedule_cron_job -- schedules/updates a recurring background job rule
  # options_hash [Hash] 
  #    name: <string>
  #    cron:  <string>
  #    class:  <string>
  #    args:  <activity-args array>
  # ------------------------------------------------------------
  def self.schedule_cron_job(options_hash)
    Environ.log_info("KipangaScheduler: schedules/updates cron: #{options_hash[:name]}")
    Sidekiq::Cron::Job.create(options_hash)
  end

  #  ------------------------------------------------------------
  #  schedule_nop_activity -- queues a nop activity to verify sidekiq
  #  ------------------------------------------------------------
  def self.schedule_nop_activity
    Environ.log_info("KipangaScheduler: [TEST] Queuing NOP job...")
    self.schedule_job_now()
  end

  #  ------------------------------------------------------------
  #  schedule_nop_script --  schedules an empty script for execution
  #  ------------------------------------------------------------
  def self.schedule_nop_script   

    # Calculate the target time to be 3 min from now
    target_time = Time.now + (3 * 60) # 3 minutes from now
    
    # Format the time as a 5-field cron string: "Min Hour Day Month DayOfWeek"
    # This will run once at the specified time.
    cron_string = target_time.strftime("%M %H %d %m %w")
    Environ.log_info("KipangaScheduler: NOP script scheduled for: #{cron_string}...")

    options_hash = {
      name: "NOP Script Test",
      cron: cron_string,
      class: 'Kipangaratiba::ShellWorker' ,
      args: ["bash ~/bin/nop_test.sh 'Scheduled cron (3 min)' "]  # <-- activity_args passed to ShellWorker#perform
    }
    self.schedule_cron_job(options_hash) # Calls wrapper   )
  end

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------
private

  # ------------------------------------------------------------
  # setup_sidekiq_config -- Configures Sidekiq client and server
  # Connects Sidekiq to the local Redis instance.
  # ------------------------------------------------------------
  def setup_sidekiq_config
    Sidekiq.configure_server do |config|
      config.redis = { url: 'redis://localhost:6379/0' }
      Environ.log_info("KipangaScheduler: Sidekiq server configured for Redis.")
    end

    Sidekiq.configure_client do |config|
      config.redis = { url: 'redis://localhost:6379/0' } 
      Environ.log_info("KipangaScheduler: Sidekiq client configured for Redis.")
    end
  end # setup_sidekiq_config
  #  ------------------------------------------------------------
  #  ------------------------------------------------------------


end  # Class KipangaScheduler

end  # module Kipangaratiba

