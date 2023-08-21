# frozen_string_literal: true

require 'rails_helper'

describe UserMailer do
  let(:receiver) { Fabricate(:user) }

  describe 'confirmation_instructions' do
    let(:mail) { described_class.confirmation_instructions(receiver, 'spec') }

    it 'renders confirmation instructions' do
      receiver.update!(locale: nil)
      expect(mail.body.encoded).to include I18n.t('devise.mailer.confirmation_instructions.title')
      expect(mail.body.encoded).to include 'spec'
      expect(mail.body.encoded).to include Rails.configuration.x.local_domain
    end

    include_examples 'localized subject',
                     'devise.mailer.confirmation_instructions.subject',
                     instance: Rails.configuration.x.local_domain
  end

  describe 'reconfirmation_instructions' do
    let(:mail) { described_class.confirmation_instructions(receiver, 'spec') }

    it 'renders reconfirmation instructions' do
      receiver.update!(email: 'new-email@example.com', locale: nil)
      expect(mail.body.encoded).to include I18n.t('devise.mailer.reconfirmation_instructions.title')
      expect(mail.body.encoded).to include 'spec'
      expect(mail.body.encoded).to include Rails.configuration.x.local_domain
      expect(mail.subject).to eq I18n.t('devise.mailer.reconfirmation_instructions.subject',
                                        instance: Rails.configuration.x.local_domain,
                                        locale: I18n.default_locale)
    end
  end

  describe 'reset_password_instructions' do
    let(:mail) { described_class.reset_password_instructions(receiver, 'spec') }

    it 'renders reset password instructions' do
      receiver.update!(locale: nil)
      expect(mail.body.encoded).to include I18n.t('devise.mailer.reset_password_instructions.title')
      expect(mail.body.encoded).to include 'spec'
    end

    include_examples 'localized subject',
                     'devise.mailer.reset_password_instructions.subject'
  end

  describe 'password_change' do
    let(:mail) { described_class.password_change(receiver) }

    it 'renders password change notification' do
      receiver.update!(locale: nil)
      expect(mail.body.encoded).to include I18n.t('devise.mailer.password_change.title')
    end

    include_examples 'localized subject',
                     'devise.mailer.password_change.subject'
  end

  describe 'email_changed' do
    let(:mail) { described_class.email_changed(receiver) }

    it 'renders email change notification' do
      receiver.update!(locale: nil)
      expect(mail.body.encoded).to include I18n.t('devise.mailer.email_changed.title')
    end

    include_examples 'localized subject',
                     'devise.mailer.email_changed.subject'
  end

  describe 'warning' do
    let(:strike) { Fabricate(:account_warning, target_account: receiver.account, text: 'dont worry its just the testsuite', action: 'suspend') }
    let(:mail)   { described_class.warning(receiver, strike) }

    it 'renders warning notification' do
      receiver.update!(locale: nil)
      expect(mail.body.encoded).to include I18n.t('user_mailer.warning.title.suspend', acct: receiver.account.acct)
      expect(mail.body.encoded).to include strike.text
    end
  end

  describe 'webauthn_credential_deleted' do
    let(:credential) { Fabricate(:webauthn_credential, user_id: receiver.id) }
    let(:mail) { described_class.webauthn_credential_deleted(receiver, credential) }

    it 'renders webauthn credential deleted notification' do
      receiver.update!(locale: nil)
      expect(mail.body.encoded).to include I18n.t('devise.mailer.webauthn_credential.deleted.title')
    end

    include_examples 'localized subject',
                     'devise.mailer.webauthn_credential.deleted.subject'
  end

  describe 'suspicious_sign_in' do
    let(:ip) { '192.168.0.1' }
    let(:agent) { 'NCSA_Mosaic/2.0 (Windows 3.1)' }
    let(:timestamp) { Time.now.utc }
    let(:mail) { described_class.suspicious_sign_in(receiver, ip, agent, timestamp) }

    it 'renders suspicious sign in notification' do
      receiver.update!(locale: nil)
      expect(mail.body.encoded).to include I18n.t('user_mailer.suspicious_sign_in.explanation')
    end

    include_examples 'localized subject',
                     'user_mailer.suspicious_sign_in.subject'
  end

  describe 'appeal_approved' do
    let(:appeal) { Fabricate(:appeal, account: receiver.account, approved_at: Time.now.utc) }
    let(:mail) { described_class.appeal_approved(receiver, appeal) }

    it 'renders appeal_approved notification' do
      expect(mail.subject).to eq I18n.t('user_mailer.appeal_approved.subject', date: I18n.l(appeal.created_at))
      expect(mail.body.encoded).to include I18n.t('user_mailer.appeal_approved.title')
    end
  end

  describe 'appeal_rejected' do
    let(:appeal) { Fabricate(:appeal, account: receiver.account, rejected_at: Time.now.utc) }
    let(:mail) { described_class.appeal_rejected(receiver, appeal) }

    it 'renders appeal_rejected notification' do
      expect(mail.subject).to eq I18n.t('user_mailer.appeal_rejected.subject', date: I18n.l(appeal.created_at))
      expect(mail.body.encoded).to include I18n.t('user_mailer.appeal_rejected.title')
    end
  end

  describe 'two_factor_enabled' do
    let(:mail) { described_class.two_factor_enabled(receiver) }

    it 'renders two_factor_enabled mail' do
      expect(mail.subject).to eq I18n.t('devise.mailer.two_factor_enabled.subject')
      expect(mail.body.encoded).to include I18n.t('devise.mailer.two_factor_enabled.explanation')
    end
  end

  describe 'two_factor_disabled' do
    let(:mail) { described_class.two_factor_disabled(receiver) }

    it 'renders two_factor_disabled mail' do
      expect(mail.subject).to eq I18n.t('devise.mailer.two_factor_disabled.subject')
      expect(mail.body.encoded).to include I18n.t('devise.mailer.two_factor_disabled.explanation')
    end
  end

  describe 'webauthn_enabled' do
    let(:mail) { described_class.webauthn_enabled(receiver) }

    it 'renders webauthn_enabled mail' do
      expect(mail.subject).to eq I18n.t('devise.mailer.webauthn_enabled.subject')
      expect(mail.body.encoded).to include I18n.t('devise.mailer.webauthn_enabled.explanation')
    end
  end

  describe 'webauthn_disabled' do
    let(:mail) { described_class.webauthn_disabled(receiver) }

    it 'renders webauthn_disabled mail' do
      expect(mail.subject).to eq I18n.t('devise.mailer.webauthn_disabled.subject')
      expect(mail.body.encoded).to include I18n.t('devise.mailer.webauthn_disabled.explanation')
    end
  end

  describe 'two_factor_recovery_codes_changed' do
    let(:mail) { described_class.two_factor_recovery_codes_changed(receiver) }

    it 'renders two_factor_recovery_codes_changed mail' do
      expect(mail.subject).to eq I18n.t('devise.mailer.two_factor_recovery_codes_changed.subject')
      expect(mail.body.encoded).to include I18n.t('devise.mailer.two_factor_recovery_codes_changed.explanation')
    end
  end

  describe 'webauthn_credential_added' do
    let(:credential) { Fabricate.build(:webauthn_credential) }
    let(:mail) { described_class.webauthn_credential_added(receiver, credential) }

    it 'renders webauthn_credential_added mail' do
      expect(mail.subject).to eq I18n.t('devise.mailer.webauthn_credential.added.subject')
      expect(mail.body.encoded).to include I18n.t('devise.mailer.webauthn_credential.added.explanation')
    end
  end
end
