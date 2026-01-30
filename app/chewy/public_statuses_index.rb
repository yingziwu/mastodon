# frozen_string_literal: true

class PublicStatusesIndex < Chewy::Index
  include DatetimeClampingConcern

  settings index: index_preset(refresh_interval: '30s', number_of_shards: 5), analysis: {
    filter: {
      english_stop: {
        type: 'stop',
        stopwords: '_english_',
      },

      english_stemmer: {
        type: 'stemmer',
        language: 'english',
      },

      english_possessive_stemmer: {
        type: 'stemmer',
        language: 'possessive_english',
      },

      tsconvert: {
        type: "stconvert",
        delimiter: "#",
        keep_both: false,
        convert_type: "t2s"
      }
    },

    char_filter: {
      tsconvert: {
        type: 'stconvert',
        convert_type: 't2s',
      },
    },

    analyzer: {
      verbatim: {
        tokenizer: 'uax_url_email',
        filter: %w(lowercase),
      },

      content: {
        tokenizer: 'ik_max_word',
        filter: %w(
          lowercase
          asciifolding
          cjk_width
          elision
          english_possessive_stemmer
          english_stop
          english_stemmer
        ),
        char_filter: %w(tsconvert),
      },

      content_search: {
        tokenizer: 'ik_smart',
        filter: %w(
          lowercase
          asciifolding
          cjk_width
          elision
          english_possessive_stemmer
          english_stop
          english_stemmer
        ),
        char_filter: %w(tsconvert),
      },

      hashtag: {
        tokenizer: 'keyword',
        filter: %w(
          word_delimiter_graph
          lowercase
          asciifolding
          cjk_width
        ),
        char_filter: %w(tsconvert),
      },
    },
  }

  index_scope ::Status.unscoped
                      .kept
                      .indexable
                      .includes(:media_attachments, :preloadable_poll, :tags, preview_cards_status: :preview_card)

  root date_detection: false do
    field(:id, type: 'long')
    field(:account_id, type: 'long')
    field(:text, type: 'text', analyzer: 'verbatim', value: ->(status) { status.searchable_text }) { field(:stemmed, type: 'text', analyzer: 'content', search_analyzer: 'content_search') }
    field(:tags, type: 'text', analyzer: 'hashtag', value: ->(status) { status.tags.map(&:display_name) })
    field(:language, type: 'keyword')
    field(:properties, type: 'keyword', value: ->(status) { status.searchable_properties })
    field(:created_at, type: 'date', value: ->(status) { clamp_date(status.created_at) })
  end
end
