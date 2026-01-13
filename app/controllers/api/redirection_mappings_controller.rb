module Api
  class RedirectionMappingsController < ApplicationController
    def index
      @redirection_mappings = RedirectionMapping.where(active: true)
    end
  end
end
