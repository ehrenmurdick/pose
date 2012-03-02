module Pose
  module BaseAdditions

    def posify &block
      raise "You must provide a block that returns the searchable content to 'posify'." unless block_given?
      include Pose::ModelAdditions
      self.pose_content = block
    end

  end
end
