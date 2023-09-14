# frozen_string_literal: true

class Api::V1::Admin::TagsController < Api::BaseController
  include Authorization
  before_action -> { authorize_if_got_token! :'admin:read' }, only: [:index, :show]
  before_action -> { authorize_if_got_token! :'admin:write' }, only: :update

  before_action :set_tags, only: :index
  before_action :set_tag, except: :index

  after_action :insert_pagination_headers, only: :index
  after_action :verify_authorized

  LIMIT = 100
  PAGINATION_PARAMS = %i(limit).freeze

  def index
    authorize :tag, :index?
    render json: @tags, each_serializer: REST::Admin::TagSerializer
  end

  def show
    authorize @tag, :show?
    render json: @tag, serializer: REST::Admin::TagSerializer
  end

  def update
    authorize @tag, :update?
    @tag.update!(tag_params.merge(reviewed_at: Time.now.utc))
    render json: @tag, serializer: REST::Admin::TagSerializer
  end

  private

  def set_tag
    @tag = Tag.find(params[:id])
  end

  def set_tags
    @tags = Tag.all.to_a_paginated_by_id(limit_param(LIMIT), params_slice(:max_id, :since_id, :min_id))
  end

  def tag_params
    params.permit(:display_name, :trendable, :usable, :listable)
  end

  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def next_path
    api_v1_admin_tags_url(pagination_params(max_id: pagination_max_id)) if records_continue?
  end

  def prev_path
    api_v1_admin_tags_url(pagination_params(min_id: pagination_since_id)) unless @tags.empty?
  end

  def pagination_max_id
    @tags.last.id
  end

  def pagination_since_id
    @tags.first.id
  end

  def records_continue?
    @tags.size == limit_param(LIMIT)
  end

  def pagination_params(core_params)
    params.slice(*PAGINATION_PARAMS).permit(*PAGINATION_PARAMS).merge(core_params)
  end
end
