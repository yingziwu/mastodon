# frozen_string_literal: true

class Disputes::BaseController < ApplicationController
  include Authorization

  layout 'admin'

  skip_before_action :require_functional!

  before_action :set_body_classes
  before_action :authenticate_user!
  before_action :set_cache_headers

  private

  def set_body_classes
    @body_classes = 'admin'
  end

  def set_cache_headers
    response.cache_control.replace(private: true, no_store: true)
  end
end
