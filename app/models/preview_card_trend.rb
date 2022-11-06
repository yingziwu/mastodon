# frozen_string_literal: true

# == Schema Information
#
# Table name: preview_card_trends
#
#  id              :bigint(8)        not null, primary key
#  preview_card_id :bigint(8)        not null
#  score           :float            default(0.0), not null
#  rank            :integer          default(0), not null
#  allowed         :boolean          default(FALSE), not null
#  language        :string
#
class PreviewCardTrend < ApplicationRecord
  belongs_to :preview_card
  scope :allowed, -> { where(allowed: true) }
end
