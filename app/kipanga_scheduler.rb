# --- kipanga_scheduler.rb ---
#
# Kipangaratiba:
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#

require 'singleton'
require 'yaml'
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

  # --- Private Class Constant for Day Mapping ---
  DAY_OF_WEEK_MAP = {
    'sunday'    => 0,
    'monday'    => 1,
    'tuesday'   => 2,
    'wednesday' => 3,
    'thursday'  => 4,
    'friday'    => 5,
    'saturday'  => 6
  }.freeze
  
  private_constant :DAY_OF_WEEK_MAP
  # ------------------------------------------------------------

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

  # ------------------------------------------------------------
  # --- BUSINESS LOGIC METHODS (Loading Schedule) ---
  # ------------------------------------------------------------

  #  ------------------------------------------------------------
  #  self.load_schedule_from_yml -- loads and schedules all meetings
  #  file_path [String] -- path to the YAML schedule file
  #  ------------------------------------------------------------
  def self.load_schedule_from_yml(file_path)
    Environ.log_info("KipangaScheduler: Loading schedule from #{file_path}...")
    begin
      schedule_data = YAML.load_file(file_path)
      schedule_data.each do |meeting_hash|
        self.schedule_a_meeting(meeting_hash)
      end
    rescue => e
      Environ.log_error("KipangaScheduler: FAILED to load schedule: #{e.message}")
    end
  end

  #  ------------------------------------------------------------
  #  self.schedule_a_meeting -- translates a meeting hash into a cron job
  #  meeting_hash [Hash] -- a single meeting definition from YAML
  #  ------------------------------------------------------------
  def self.schedule_a_meeting(meeting_hash)
    # Get meeting details
    meeting_name = meeting_hash['meeting']
    week_day_str = meeting_hash['week_day']&.downcase
    start_time   = meeting_hash['start_time']
    stop_time    = meeting_hash['stop_time'] # Will be nil if not present

    # Translate day_of_week, with default
    day_of_week = DAY_OF_WEEK_MAP[week_day_str]
    day_name_for_job = ''

    if day_of_week.nil?
      Environ.log_warn("KipangaScheduler: Invalid day '#{week_day_str}'. Defaulting to Monday.")
      day_of_week = DAY_OF_WEEK_MAP['monday'] # Default to 1
      day_name_for_job = 'Monday'
    else
      day_name_for_job = week_day_str.capitalize
    end

    # Create the START Job ---
    self._build_and_schedule(
      meeting_name,
      'Start',
      start_time,
      day_of_week,
      day_name_for_job
    )

    # Create the STOP Job ---
    self._build_and_schedule(
      meeting_name,
      'Stop',
      stop_time,
      day_of_week,
      day_name_for_job
    )
  end # self.schedule_a_meeting


  #  ------------------------------------------------------------
  #  setup_meetings -- loads schedule from yml; optionally resets cron
  #  filename [String] -- path to the YAML schedule file
  #  resetcron [Boolean] -- if true, deletes all old cron jobs first
  #  ------------------------------------------------------------
  def setup_meetings(filename, resetcron: true)
    if resetcron
      Sidekiq::Cron::Job.destroy_all!
      Environ.log_info("KipangaScheduler: Cleared all old cron jobs.")
    end

    # Load the schedule
    KipangaScheduler.load_schedule_from_yml(filename)
  end

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

private

    #  ------------------------------------------------------------
    #  _build_and_schedule -- helper to build and schedule a single job
    #  (Skips if time_str is nil or empty)
    #  meeting_name [String] -- name of the meeting
    #  job_type [String] -- 'Start' or 'Stop'
    #  time_str [String] -- 'HH:MM'
    #  day_of_week [Integer] -- 0-6
    #  day_name [String] -- 'Monday'
    #  ------------------------------------------------------------
    def self._build_and_schedule(meeting_name, job_type, time_str, day_of_week, day_name)
      
      # Check if the time is provided before proceeding
      if time_str && !time_str.to_s.empty?
        # Parse time
        hour, min = time_str.to_s.split(':').map(&:to_i)
        
        # Build cron string
        cron_string = "#{min} #{hour} * * #{day_of_week}"
        
        # Build command string based on type
        command_string = ""

        if job_type == 'Start'
          # START_SCRIPT_TEMPLATE requires string formatting
          command_string = sprintf(
            Environ::START_SCRIPT_TEMPLATE,
            meeting_name: meeting_name
          )
        else # 'Stop'
          # STOP_SCRIPT_TEMPLATE is a static string
          command_string = Environ::STOP_SCRIPT_TEMPLATE
        end   # fi..else start/stop check

        # Build job name
        job_name = "#{meeting_name} (#{job_type} - #{day_name})"
        
        # Build options hash
        options_hash = {
          name:  job_name,
          cron:  cron_string,
          class: 'Kipangaratiba::ShellWorker',
          args:  [command_string]
        }
        
        # Call the generic wrapper
        self.schedule_cron_job(options_hash)

      else  # missing/empty time_str; gracefully ignore & log it
        # Log that we are intentionally skipping this job
        Environ.log_info("KipangaScheduler: No '#{job_type}' time for '#{meeting_name}'. Skipping.")
      end  # fi..else.. missing time_str

    end   # def _build_and_schedule

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

