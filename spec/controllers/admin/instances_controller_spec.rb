# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::InstancesController do
  render_views

  let(:current_user) { Fabricate(:user, role: UserRole.find_by(name: 'Admin')) }

  let!(:account_popular_main) { Fabricate(:account, domain: 'popular') }
  let!(:account_popular_other) { Fabricate(:account, domain: 'popular') }
  let!(:account_less_popular) { Fabricate(:account, domain: 'less.popular') }

  before do
    sign_in current_user, scope: :user
  end

  describe 'GET #index' do
    around do |example|
      default_per_page = Instance.default_per_page
      Instance.paginates_per 1
      example.run
      Instance.paginates_per default_per_page
    end

    it 'renders instances' do
      get :index, params: { page: 2 }

      instances = assigns(:instances).to_a
      expect(instances.size).to eq 1
      expect(instances[0].domain).to eq 'less.popular'

      expect(response).to have_http_status(200)
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { id: Instance.first.id } }

    let(:current_user) { Fabricate(:user, role: role) }
    let(:account) { Fabricate(:account) }

    context 'when user is admin' do
      let(:role) { UserRole.find_by(name: 'Admin') }

      it 'succeeds in purging instance' do
        expect(subject).to redirect_to admin_instances_path
      end
    end

    context 'when user is not admin' do
      let(:role) { nil }

      it 'fails to purge instance' do
        expect(subject).to have_http_status 403
      end
    end
  end
end
