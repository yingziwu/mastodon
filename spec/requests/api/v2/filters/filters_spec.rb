# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Filters' do
  let(:user)    { Fabricate(:user) }
  let(:scopes)  { 'read:filters write:filters' }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

  shared_examples 'unauthorized for invalid token' do
    let(:headers) { { 'Authorization' => '' } }

    it 'returns http unauthorized' do
      subject

      expect(response).to have_http_status(401)
    end
  end

  describe 'GET /api/v2/filters' do
    subject do
      get '/api/v2/filters', headers: headers
    end

    let!(:filters) { Fabricate.times(3, :custom_filter, account: user.account) }

    it_behaves_like 'forbidden for wrong scope', 'write write:filters'
    it_behaves_like 'unauthorized for invalid token'

    it 'returns the existing filters successfully', :aggregate_failures do
      subject

      expect(response).to have_http_status(200)
      expect(body_as_json.pluck(:id)).to match_array(filters.map { |filter| filter.id.to_s })
    end
  end

  describe 'POST /api/v2/filters' do
    subject do
      post '/api/v2/filters', params: params, headers: headers
    end

    let(:params) { {} }

    it_behaves_like 'forbidden for wrong scope', 'read read:filters'
    it_behaves_like 'unauthorized for invalid token'

    context 'with valid params' do
      let(:params) { { title: 'magic', context: %w(home), filter_action: 'hide', keywords_attributes: [keyword: 'magic'] } }

      it 'returns http success' do
        subject

        expect(response).to have_http_status(200)
      end

      it 'returns a filter with keywords', :aggregate_failures do
        subject

        json = body_as_json

        expect(json[:title]).to eq 'magic'
        expect(json[:filter_action]).to eq 'hide'
        expect(json[:context]).to eq ['home']
        expect(json[:keywords].map { |keyword| keyword.slice(:keyword, :whole_word) }).to eq [{ keyword: 'magic', whole_word: true }]
      end

      it 'creates a filter', :aggregate_failures do
        subject

        filter = user.account.custom_filters.first

        expect(filter).to be_present
        expect(filter.keywords.pluck(:keyword)).to eq ['magic']
        expect(filter.context).to eq %w(home)
        expect(filter.irreversible?).to be true
        expect(filter.expires_at).to be_nil
      end
    end

    context 'when the required title param is missing' do
      let(:params) { { context: %w(home), filter_action: 'hide', keywords_attributes: [keyword: 'magic'] } }

      it 'returns http unprocessable entity' do
        subject

        expect(response).to have_http_status(422)
      end
    end

    context 'when the required context param is missing' do
      let(:params) { { title: 'magic', filter_action: 'hide', keywords_attributes: [keyword: 'magic'] } }

      it 'returns http unprocessable entity' do
        subject

        expect(response).to have_http_status(422)
      end
    end

    context 'when the given context value is invalid' do
      let(:params) { { title: 'magic', context: %w(shaolin), filter_action: 'hide', keywords_attributes: [keyword: 'magic'] } }

      it 'returns http unprocessable entity' do
        subject

        expect(response).to have_http_status(422)
      end
    end
  end

  describe 'GET /api/v2/filters/:id' do
    subject do
      get "/api/v2/filters/#{filter.id}", headers: headers
    end

    let(:filter) { Fabricate(:custom_filter, account: user.account) }

    it_behaves_like 'forbidden for wrong scope', 'write write:filters'
    it_behaves_like 'unauthorized for invalid token'

    it 'returns the filter successfully', :aggregate_failures do
      subject

      expect(response).to have_http_status(200)
      expect(body_as_json[:id]).to eq(filter.id.to_s)
    end

    context 'when the filter belongs to someone else' do
      let(:filter) { Fabricate(:custom_filter) }

      it 'returns http not found' do
        subject

        expect(response).to have_http_status(404)
      end
    end
  end

  describe 'PUT /api/v2/filters/:id' do
    subject do
      put "/api/v2/filters/#{filter.id}", params: params, headers: headers
    end

    let!(:filter)  { Fabricate(:custom_filter, account: user.account) }
    let!(:keyword) { Fabricate(:custom_filter_keyword, custom_filter: filter) }
    let(:params)   { {} }

    it_behaves_like 'forbidden for wrong scope', 'read read:filters'
    it_behaves_like 'unauthorized for invalid token'

    context 'when updating filter parameters' do
      context 'with valid params' do
        let(:params) { { title: 'updated', context: %w(home public) } }

        it 'updates the filter successfully', :aggregate_failures do
          subject

          filter.reload

          expect(response).to have_http_status(200)
          expect(filter.title).to eq 'updated'
          expect(filter.reload.context).to eq %w(home public)
        end
      end

      context 'with invalid params' do
        let(:params) { { title: 'updated', context: %w(word) } }

        it 'returns http unprocessable entity' do
          subject

          expect(response).to have_http_status(422)
        end
      end
    end

    context 'when updating keywords in bulk' do
      let(:params) { { keywords_attributes: [{ id: keyword.id, keyword: 'updated' }] } }

      before do
        allow(redis).to receive_messages(publish: nil)
      end

      it 'returns http success' do
        subject

        expect(response).to have_http_status(200)
      end

      it 'updates the keyword' do
        subject

        expect(keyword.reload.keyword).to eq 'updated'
      end

      it 'sends exactly one filters_changed event' do
        subject

        expect(redis).to have_received(:publish).with("timeline:#{user.account.id}", Oj.dump(event: :filters_changed)).once
      end
    end

    context 'when the filter belongs to someone else' do
      let(:filter) { Fabricate(:custom_filter) }

      it 'returns http not found' do
        subject

        expect(response).to have_http_status(404)
      end
    end
  end

  describe 'DELETE /api/v2/filters/:id' do
    subject do
      delete "/api/v2/filters/#{filter.id}", headers: headers
    end

    let(:filter) { Fabricate(:custom_filter, account: user.account) }

    it_behaves_like 'forbidden for wrong scope', 'read read:filters'
    it_behaves_like 'unauthorized for invalid token'

    it 'returns http success' do
      subject

      expect(response).to have_http_status(200)
    end

    it 'removes the filter' do
      subject

      expect { filter.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    context 'when the filter belongs to someone else' do
      let(:filter) { Fabricate(:custom_filter) }

      it 'returns http not found' do
        subject

        expect(response).to have_http_status(404)
      end
    end
  end
end
