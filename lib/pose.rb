# Note (KG): Need to include the rake DSL here to prevent deprecation warnings in the Rakefile.
require 'rake'
include Rake::DSL if defined? Rake::DSL

require 'pose/static_api'
require 'pose/internal_helpers'
require 'pose/activerecord_base_additions'
require 'pose/model_additions'
require 'pose/railtie' if defined? Rails
require 'pose/models/pose_assignment'
require 'pose/models/pose_word'
