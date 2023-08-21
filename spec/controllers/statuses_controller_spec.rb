# frozen_string_literal: true

require 'rails_helper'

describe StatusesController do
  render_views

  shared_examples 'cacheable response' do
    it 'does not set cookies' do
      expect(response.cookies).to be_empty
      expect(response.headers['Set-Cookies']).to be_nil
    end

    it 'does not set sessions' do
      expect(session).to be_empty
    end

    it 'returns Vary header' do
      expect(response.headers['Vary']).to include 'Accept, Accept-Language, Cookie'
    end

    it 'returns public Cache-Control header' do
      expect(response.headers['Cache-Control']).to include 'public'
    end
  end

  describe 'GET #show' do
    let(:account) { Fabricate(:account) }
    let(:status)  { Fabricate(:status, account: account) }

    context 'when account is permanently suspended' do
      before do
        account.suspend!
        account.deletion_request.destroy

        get :show, params: { account_username: account.username, id: status.id }
      end

      it 'returns http gone' do
        expect(response).to have_http_status(410)
      end
    end

    context 'when account is temporarily suspended' do
      before do
        account.suspend!

        get :show, params: { account_username: account.username, id: status.id }
      end

      it 'returns http forbidden' do
        expect(response).to have_http_status(403)
      end
    end

    context 'when status is a reblog' do
      let(:original_account) { Fabricate(:account, domain: 'example.com') }
      let(:original_status) { Fabricate(:status, account: original_account, url: 'https://example.com/123') }
      let(:status) { Fabricate(:status, account: account, reblog: original_status) }

      before do
        get :show, params: { account_username: status.account.username, id: status.id }
      end

      it 'redirects to the original status' do
        expect(response).to redirect_to(original_status.url)
      end
    end

    context 'when status is public' do
      before do
        get :show, params: { account_username: status.account.username, id: status.id, format: format }
      end

      context 'with HTML' do
        let(:format) { 'html' }

        it 'renders status successfully', :aggregate_failures do
          expect(response).to have_http_status(200)
          expect(response.headers['Link'].to_s).to include 'activity+json'
          expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
          expect(response.headers['Cache-Control']).to include 'public'
          expect(response).to render_template(:show)
          expect(response.body).to include status.text
        end
      end

      context 'with JSON' do
        let(:format) { 'json' }

        it_behaves_like 'cacheable response'

        it 'renders ActivityPub Note object successfully', :aggregate_failures do
          expect(response).to have_http_status(200)
          expect(response.headers['Link'].to_s).to include 'activity+json'
          expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
          expect(response.headers['Content-Type']).to include 'application/activity+json'
          json = body_as_json
          expect(json[:content]).to include status.text
        end
      end
    end

    context 'when status is private' do
      let(:status) { Fabricate(:status, account: account, visibility: :private) }

      before do
        get :show, params: { account_username: status.account.username, id: status.id, format: format }
      end

      context 'with JSON' do
        let(:format) { 'json' }

        it 'returns http not found' do
          expect(response).to have_http_status(404)
        end
      end

      context 'with HTML' do
        let(:format) { 'html' }

        it 'returns http not found' do
          expect(response).to have_http_status(404)
        end
      end
    end

    context 'when status is direct' do
      let(:status) { Fabricate(:status, account: account, visibility: :direct) }

      before do
        get :show, params: { account_username: status.account.username, id: status.id, format: format }
      end

      context 'with JSON' do
        let(:format) { 'json' }

        it 'returns http not found' do
          expect(response).to have_http_status(404)
        end
      end

      context 'with HTML' do
        let(:format) { 'html' }

        it 'returns http not found' do
          expect(response).to have_http_status(404)
        end
      end
    end

    context 'when signed-in' do
      let(:user) { Fabricate(:user) }

      before do
        sign_in(user)
      end

      context 'when account blocks user' do
        before do
          account.block!(user.account)
          get :show, params: { account_username: status.account.username, id: status.id }
        end

        it 'returns http not found' do
          expect(response).to have_http_status(404)
        end
      end

      context 'when status is public' do
        before do
          get :show, params: { account_username: status.account.username, id: status.id, format: format }
        end

        context 'with HTML' do
          let(:format) { 'html' }

          it 'renders status successfully', :aggregate_failures do
            expect(response).to have_http_status(200)
            expect(response.headers['Link'].to_s).to include 'activity+json'
            expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
            expect(response.headers['Cache-Control']).to include 'private'
            expect(response).to render_template(:show)
            expect(response.body).to include status.text
          end
        end

        context 'with JSON' do
          let(:format) { 'json' }

          it 'renders ActivityPub Note object successfully', :aggregate_failures do
            expect(response).to have_http_status(200)
            expect(response.headers['Link'].to_s).to include 'activity+json'
            expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
            expect(response.headers['Cache-Control']).to include 'private'
            expect(response.headers['Content-Type']).to include 'application/activity+json'
            json = body_as_json
            expect(json[:content]).to include status.text
          end
        end
      end

      context 'when status is private' do
        let(:status) { Fabricate(:status, account: account, visibility: :private) }

        context 'when user is authorized to see it' do
          before do
            user.account.follow!(account)
            get :show, params: { account_username: status.account.username, id: status.id, format: format }
          end

          context 'with HTML' do
            let(:format) { 'html' }

            it 'renders status successfully', :aggregate_failures do
              expect(response).to have_http_status(200)
              expect(response.headers['Link'].to_s).to include 'activity+json'
              expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
              expect(response.headers['Cache-Control']).to include 'private'
              expect(response).to render_template(:show)
              expect(response.body).to include status.text
            end
          end

          context 'with JSON' do
            let(:format) { 'json' }

            it 'renders ActivityPub Note object successfully', :aggregate_failures do
              expect(response).to have_http_status(200)
              expect(response.headers['Link'].to_s).to include 'activity+json'
              expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
              expect(response.headers['Cache-Control']).to include 'private'
              expect(response.headers['Content-Type']).to include 'application/activity+json'
              json = body_as_json
              expect(json[:content]).to include status.text
            end
          end
        end

        context 'when user is not authorized to see it' do
          before do
            get :show, params: { account_username: status.account.username, id: status.id, format: format }
          end

          context 'with JSON' do
            let(:format) { 'json' }

            it 'returns http not found' do
              expect(response).to have_http_status(404)
            end
          end

          context 'with HTML' do
            let(:format) { 'html' }

            it 'returns http not found' do
              expect(response).to have_http_status(404)
            end
          end
        end
      end

      context 'when status is direct' do
        let(:status) { Fabricate(:status, account: account, visibility: :direct) }

        context 'when user is authorized to see it' do
          before do
            Fabricate(:mention, account: user.account, status: status)
            get :show, params: { account_username: status.account.username, id: status.id, format: format }
          end

          context 'with HTML' do
            let(:format) { 'html' }

            it 'renders status successfully', :aggregate_failures do
              expect(response).to have_http_status(200)
              expect(response.headers['Link'].to_s).to include 'activity+json'
              expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
              expect(response.headers['Cache-Control']).to include 'private'
              expect(response).to render_template(:show)
              expect(response.body).to include status.text
            end
          end

          context 'with JSON' do
            let(:format) { 'json' }

            it 'renders ActivityPub Note object successfully' do
              expect(response).to have_http_status(200)
              expect(response.headers['Link'].to_s).to include 'activity+json'
              expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
              expect(response.headers['Cache-Control']).to include 'private'
              expect(response.headers['Content-Type']).to include 'application/activity+json'
              json = body_as_json
              expect(json[:content]).to include status.text
            end
          end
        end

        context 'when user is not authorized to see it' do
          before do
            get :show, params: { account_username: status.account.username, id: status.id, format: format }
          end

          context 'with JSON' do
            let(:format) { 'json' }

            it 'returns http not found' do
              expect(response).to have_http_status(404)
            end
          end

          context 'with HTML' do
            let(:format) { 'html' }

            it 'returns http not found' do
              expect(response).to have_http_status(404)
            end
          end
        end
      end
    end

    context 'with signature' do
      let(:remote_account) { Fabricate(:account, domain: 'example.com') }

      before do
        allow(controller).to receive(:signed_request_actor).and_return(remote_account)
      end

      context 'when account blocks account' do
        before do
          account.block!(remote_account)
          get :show, params: { account_username: status.account.username, id: status.id }
        end

        it 'returns http not found' do
          expect(response).to have_http_status(404)
        end
      end

      context 'when account domain blocks account' do
        before do
          account.block_domain!(remote_account.domain)
          get :show, params: { account_username: status.account.username, id: status.id }
        end

        it 'returns http not found' do
          expect(response).to have_http_status(404)
        end
      end

      context 'when status is public' do
        before do
          get :show, params: { account_username: status.account.username, id: status.id, format: format }
        end

        context 'with HTML' do
          let(:format) { 'html' }

          it 'renders status successfully', :aggregate_failures do
            expect(response).to have_http_status(200)
            expect(response.headers['Link'].to_s).to include 'activity+json'
            expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
            expect(response.headers['Cache-Control']).to include 'private'
            expect(response).to render_template(:show)
            expect(response.body).to include status.text
          end
        end

        context 'with JSON' do
          let(:format) { 'json' }

          it_behaves_like 'cacheable response'

          it 'renders ActivityPub Note object successfully', :aggregate_failures do
            expect(response).to have_http_status(200)
            expect(response.headers['Link'].to_s).to include 'activity+json'
            expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
            expect(response.headers['Content-Type']).to include 'application/activity+json'
            json = body_as_json
            expect(json[:content]).to include status.text
          end
        end
      end

      context 'when status is private' do
        let(:status) { Fabricate(:status, account: account, visibility: :private) }

        context 'when user is authorized to see it' do
          before do
            remote_account.follow!(account)
            get :show, params: { account_username: status.account.username, id: status.id, format: format }
          end

          context 'with HTML' do
            let(:format) { 'html' }

            it 'renders status successfully', :aggregate_failures do
              expect(response).to have_http_status(200)
              expect(response.headers['Link'].to_s).to include 'activity+json'
              expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
              expect(response.headers['Cache-Control']).to include 'private'
              expect(response).to render_template(:show)
              expect(response.body).to include status.text
            end
          end

          context 'with JSON' do
            let(:format) { 'json' }

            it 'renders ActivityPub Note object successfully' do
              expect(response).to have_http_status(200)
              expect(response.headers['Link'].to_s).to include 'activity+json'
              expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
              expect(response.headers['Cache-Control']).to include 'private'
              expect(response.headers['Content-Type']).to include 'application/activity+json'
              json = body_as_json
              expect(json[:content]).to include status.text
            end
          end
        end

        context 'when user is not authorized to see it' do
          before do
            get :show, params: { account_username: status.account.username, id: status.id, format: format }
          end

          context 'with JSON' do
            let(:format) { 'json' }

            it 'returns http not found' do
              expect(response).to have_http_status(404)
            end
          end

          context 'with HTML' do
            let(:format) { 'html' }

            it 'returns http not found' do
              expect(response).to have_http_status(404)
            end
          end
        end
      end

      context 'when status is direct' do
        let(:status) { Fabricate(:status, account: account, visibility: :direct) }

        context 'when user is authorized to see it' do
          before do
            Fabricate(:mention, account: remote_account, status: status)
            get :show, params: { account_username: status.account.username, id: status.id, format: format }
          end

          context 'with HTML' do
            let(:format) { 'html' }

            it 'renders status successfully', :aggregate_failures do
              expect(response).to have_http_status(200)
              expect(response.headers['Link'].to_s).to include 'activity+json'
              expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
              expect(response.headers['Cache-Control']).to include 'private'
              expect(response).to render_template(:show)
              expect(response.body).to include status.text
            end
          end

          context 'with JSON' do
            let(:format) { 'json' }

            it 'renders ActivityPub Note object', :aggregate_failures do
              expect(response).to have_http_status(200)
              expect(response.headers['Link'].to_s).to include 'activity+json'
              expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
              expect(response.headers['Cache-Control']).to include 'private'
              expect(response.headers['Content-Type']).to include 'application/activity+json'
              json = body_as_json
              expect(json[:content]).to include status.text
            end
          end
        end

        context 'when user is not authorized to see it' do
          before do
            get :show, params: { account_username: status.account.username, id: status.id, format: format }
          end

          context 'with JSON' do
            let(:format) { 'json' }

            it 'returns http not found' do
              expect(response).to have_http_status(404)
            end
          end

          context 'with HTML' do
            let(:format) { 'html' }

            it 'returns http not found' do
              expect(response).to have_http_status(404)
            end
          end
        end
      end
    end
  end

  describe 'GET #activity' do
    let(:account) { Fabricate(:account) }
    let(:status)  { Fabricate(:status, account: account) }

    context 'when account is permanently suspended' do
      before do
        account.suspend!
        account.deletion_request.destroy

        get :activity, params: { account_username: account.username, id: status.id }
      end

      it 'returns http gone' do
        expect(response).to have_http_status(410)
      end
    end

    context 'when account is temporarily suspended' do
      before do
        account.suspend!

        get :activity, params: { account_username: account.username, id: status.id }
      end

      it 'returns http forbidden' do
        expect(response).to have_http_status(403)
      end
    end

    context 'when status is public' do
      before do
        status.update(visibility: :public)
        get :activity, params: { account_username: account.username, id: status.id }
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end
    end

    context 'when status is private' do
      before do
        status.update(visibility: :private)
        get :activity, params: { account_username: account.username, id: status.id }
      end

      it 'returns http not_found' do
        expect(response).to have_http_status(404)
      end
    end

    context 'when status is direct' do
      before do
        status.update(visibility: :direct)
        get :activity, params: { account_username: account.username, id: status.id }
      end

      it 'returns http not_found' do
        expect(response).to have_http_status(404)
      end
    end

    context 'when signed-in' do
      let(:user) { Fabricate(:user) }

      before do
        sign_in(user)
      end

      context 'when status is public' do
        before do
          status.update(visibility: :public)
          get :activity, params: { account_username: account.username, id: status.id }
        end

        it 'returns http success' do
          expect(response).to have_http_status(:success)
        end
      end

      context 'when status is private' do
        before do
          status.update(visibility: :private)
        end

        context 'when user is authorized to see it' do
          before do
            user.account.follow!(account)
            get :activity, params: { account_username: account.username, id: status.id }
          end

          it 'returns http success' do
            expect(response).to have_http_status(200)
          end
        end

        context 'when user is not authorized to see it' do
          before do
            get :activity, params: { account_username: account.username, id: status.id }
          end

          it 'returns http not_found' do
            expect(response).to have_http_status(404)
          end
        end
      end

      context 'when status is direct' do
        before do
          status.update(visibility: :direct)
        end

        context 'when user is authorized to see it' do
          before do
            Fabricate(:mention, account: user.account, status: status)
            get :activity, params: { account_username: account.username, id: status.id }
          end

          it 'returns http success' do
            expect(response).to have_http_status(200)
          end
        end

        context 'when user is not authorized to see it' do
          before do
            get :activity, params: { account_username: account.username, id: status.id }
          end

          it 'returns http not_found' do
            expect(response).to have_http_status(404)
          end
        end
      end
    end

    context 'with signature' do
      let(:remote_account) { Fabricate(:account, domain: 'example.com') }

      before do
        allow(controller).to receive(:signed_request_actor).and_return(remote_account)
      end

      context 'when status is public' do
        before do
          status.update(visibility: :public)
          get :activity, params: { account_username: account.username, id: status.id }
        end

        it 'returns http success' do
          expect(response).to have_http_status(:success)
        end
      end

      context 'when status is private' do
        before do
          status.update(visibility: :private)
        end

        context 'when user is authorized to see it' do
          before do
            remote_account.follow!(account)
            get :activity, params: { account_username: account.username, id: status.id }
          end

          it 'returns http success' do
            expect(response).to have_http_status(200)
          end
        end

        context 'when user is not authorized to see it' do
          before do
            get :activity, params: { account_username: account.username, id: status.id }
          end

          it 'returns http not_found' do
            expect(response).to have_http_status(404)
          end
        end
      end

      context 'when status is direct' do
        before do
          status.update(visibility: :direct)
        end

        context 'when user is authorized to see it' do
          before do
            Fabricate(:mention, account: remote_account, status: status)
            get :activity, params: { account_username: account.username, id: status.id }
          end

          it 'returns http success' do
            expect(response).to have_http_status(200)
          end
        end

        context 'when user is not authorized to see it' do
          before do
            get :activity, params: { account_username: account.username, id: status.id }
          end

          it 'returns http not_found' do
            expect(response).to have_http_status(404)
          end
        end
      end
    end
  end

  describe 'GET #embed' do
    let(:account) { Fabricate(:account) }
    let(:status)  { Fabricate(:status, account: account) }

    context 'when account is suspended' do
      let(:account) { Fabricate(:account, suspended: true) }

      before do
        get :embed, params: { account_username: account.username, id: status.id }
      end

      it 'returns http gone' do
        expect(response).to have_http_status(410)
      end
    end

    context 'when status is a reblog' do
      let(:original_account) { Fabricate(:account, domain: 'example.com') }
      let(:original_status) { Fabricate(:status, account: original_account, url: 'https://example.com/123') }
      let(:status) { Fabricate(:status, account: account, reblog: original_status) }

      before do
        get :embed, params: { account_username: status.account.username, id: status.id }
      end

      it 'returns http not found' do
        expect(response).to have_http_status(404)
      end
    end

    context 'when status is public' do
      before do
        get :embed, params: { account_username: status.account.username, id: status.id }
      end

      it 'renders status successfully', :aggregate_failures do
        expect(response).to have_http_status(200)
        expect(response.headers['Link'].to_s).to include 'activity+json'
        expect(response.headers['Vary']).to eq 'Accept, Accept-Language, Cookie'
        expect(response.headers['Cache-Control']).to include 'public'
        expect(response).to render_template(:embed)
        expect(response.body).to include status.text
      end
    end

    context 'when status is private' do
      let(:status) { Fabricate(:status, account: account, visibility: :private) }

      before do
        get :embed, params: { account_username: status.account.username, id: status.id }
      end

      it 'returns http not found' do
        expect(response).to have_http_status(404)
      end
    end

    context 'when status is direct' do
      let(:status) { Fabricate(:status, account: account, visibility: :direct) }

      before do
        get :embed, params: { account_username: status.account.username, id: status.id }
      end

      it 'returns http not found' do
        expect(response).to have_http_status(404)
      end
    end
  end
end
