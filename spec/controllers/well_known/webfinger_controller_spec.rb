# frozen_string_literal: true

require 'rails_helper'

describe WellKnown::WebfingerController do
  include RoutingHelper

  render_views

  describe 'GET #show' do
    subject(:perform_show!) do
      get :show, params: { resource: resource }, format: :json
    end

    let(:alternate_domains) { [] }
    let(:alice) { Fabricate(:account, username: 'alice') }
    let(:resource) { nil }

    around(:each) do |example|
      tmp = Rails.configuration.x.alternate_domains
      Rails.configuration.x.alternate_domains = alternate_domains
      example.run
      Rails.configuration.x.alternate_domains = tmp
    end

    shared_examples 'a successful response' do
      it 'returns http success' do
        expect(response).to have_http_status(200)
      end

      it 'does not set a Vary header' do
        expect(response.headers['Vary']).to be_nil
      end

      it 'returns application/jrd+json' do
        expect(response.media_type).to eq 'application/jrd+json'
      end

      it 'returns links for the account' do
        json = body_as_json
        expect(json[:subject]).to eq 'acct:alice@cb6e6126.ngrok.io'
        expect(json[:aliases]).to include('https://cb6e6126.ngrok.io/@alice', 'https://cb6e6126.ngrok.io/users/alice')
      end
    end

    context 'when an account exists' do
      let(:resource) { alice.to_webfinger_s }

      before do
        perform_show!
      end

      it_behaves_like 'a successful response'
    end

    context 'when an account is temporarily suspended' do
      let(:resource) { alice.to_webfinger_s }

      before do
        alice.suspend!
        perform_show!
      end

      it_behaves_like 'a successful response'
    end

    context 'when an account is permanently suspended or deleted' do
      let(:resource) { alice.to_webfinger_s }

      before do
        alice.suspend!
        alice.deletion_request.destroy
        perform_show!
      end

      it 'returns http gone' do
        expect(response).to have_http_status(410)
      end
    end

    context 'when an account is not found' do
      let(:resource) { 'acct:not@existing.com' }

      before do
        perform_show!
      end

      it 'returns http not found' do
        expect(response).to have_http_status(404)
      end
    end

    context 'with an alternate domain' do
      let(:alternate_domains) { ['foo.org'] }

      before do
        perform_show!
      end

      context 'when an account exists' do
        let(:resource) do
          username, = alice.to_webfinger_s.split('@')
          "#{username}@foo.org"
        end

        it_behaves_like 'a successful response'
      end

      context 'when the domain is wrong' do
        let(:resource) do
          username, = alice.to_webfinger_s.split('@')
          "#{username}@bar.org"
        end

        it 'returns http not found' do
          expect(response).to have_http_status(404)
        end
      end
    end

    context 'when the old name scheme is used to query the instance actor' do
      let(:resource) do
        "#{Rails.configuration.x.local_domain}@#{Rails.configuration.x.local_domain}"
      end

      before do
        perform_show!
      end

      it 'returns http success' do
        expect(response).to have_http_status(200)
      end

      it 'does not set a Vary header' do
        expect(response.headers['Vary']).to be_nil
      end

      it 'returns application/jrd+json' do
        expect(response.media_type).to eq 'application/jrd+json'
      end

      it 'returns links for the internal account' do
        json = body_as_json
        expect(json[:subject]).to eq 'acct:mastodon.internal@cb6e6126.ngrok.io'
        expect(json[:aliases]).to eq ['https://cb6e6126.ngrok.io/actor']
      end
    end

    context 'with no resource parameter' do
      let(:resource) { nil }

      before do
        perform_show!
      end

      it 'returns http bad request' do
        expect(response).to have_http_status(400)
      end
    end

    context 'with a nonsense parameter' do
      let(:resource) { 'df/:dfkj' }

      before do
        perform_show!
      end

      it 'returns http bad request' do
        expect(response).to have_http_status(400)
      end
    end

    context 'when an account has an avatar' do
      let(:alice) { Fabricate(:account, username: 'alice', avatar: attachment_fixture('attachment.jpg')) }
      let(:resource) { alice.to_webfinger_s }

      it 'returns avatar in response' do
        perform_show!

        avatar_link = get_avatar_link(body_as_json)
        expect(avatar_link).to_not be_nil
        expect(avatar_link[:type]).to eq alice.avatar.content_type
        expect(avatar_link[:href]).to eq full_asset_url(alice.avatar)
      end

      context 'with limited federation mode' do
        before do
          allow(Rails.configuration.x).to receive(:limited_federation_mode).and_return(true)
        end

        it 'does not return avatar in response' do
          perform_show!

          avatar_link = get_avatar_link(body_as_json)
          expect(avatar_link).to be_nil
        end
      end

      context 'when enabling DISALLOW_UNAUTHENTICATED_API_ACCESS' do
        around do |example|
          ClimateControl.modify DISALLOW_UNAUTHENTICATED_API_ACCESS: 'true' do
            example.run
          end
        end

        it 'does not return avatar in response' do
          perform_show!

          avatar_link = get_avatar_link(body_as_json)
          expect(avatar_link).to be_nil
        end
      end
    end

    context 'when an account does not have an avatar' do
      let(:alice) { Fabricate(:account, username: 'alice', avatar: nil) }
      let(:resource) { alice.to_webfinger_s }

      before do
        perform_show!
      end

      it 'does not return avatar in response' do
        avatar_link = get_avatar_link(body_as_json)
        expect(avatar_link).to be_nil
      end
    end
  end

  private

  def get_avatar_link(json)
    json[:links].find { |link| link[:rel] == 'http://webfinger.net/rel/avatar' }
  end
end
