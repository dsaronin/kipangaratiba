# --------------------------------------------------------
# Kipangaratiba: Custom Exception Definitions
# Copyright (c) 2025 David S Anderson, All Rights Reserved

# Base class for all Kipangaratiba-specific exceptions.
# Inherits from StandardError to ensure it's caught by general rescue blocks.
# --------------------------------------------------------
# --- kipangaratiba_error.rb ---
# --------------------------------------------------------

# +++++++++++++++++++++++++++++++++++++++++++++++++
module Kipangaratiba # Kipangaratiba Namespace
# +++++++++++++++++++++++++++++++++++++++++++++++++

  class KipangaratibaError < StandardError; end

  # MajorError for critical, unrecoverable configuration issues.
  class MajorError < KipangaratibaError
    def initialize(msg = "MAJOR configuration error: ")
      super(msg)
    end
  end

  # MinorError for recoverable operational issues.
  class MinorError < KipangaratibaError
    def initialize(msg = "minor operational error:")
      super(msg)
    end
  end


end # module Kipangaratiba

