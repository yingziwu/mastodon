import PropTypes from 'prop-types';

import { defineMessages, injectIntl } from 'react-intl';

import { Link } from 'react-router-dom';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';

import { Avatar } from '../../../components/avatar';
import { DisplayName } from '../../../components/display_name';
import { IconButton } from '../../../components/icon_button';

const messages = defineMessages({
  authorize: { id: 'follow_request.authorize', defaultMessage: 'Authorize' },
  reject: { id: 'follow_request.reject', defaultMessage: 'Reject' },
});

class AccountAuthorize extends ImmutablePureComponent {

  static propTypes = {
    account: ImmutablePropTypes.map.isRequired,
    onAuthorize: PropTypes.func.isRequired,
    onReject: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  render () {
    const { intl, account, onAuthorize, onReject } = this.props;
    const content = { __html: account.get('note_emojified') };

    return (
      <div className='account-authorize__wrapper'>
        <div className='account-authorize'>
          <Link to={`/@${account.get('acct')}`} className='detailed-status__display-name'>
            <div className='account-authorize__avatar'><Avatar account={account} size={48} /></div>
            <DisplayName account={account} />
          </Link>

          <div className='account__header__content translate' dangerouslySetInnerHTML={content} />
        </div>

        <div className='account--panel'>
          <div className='account--panel__button'><IconButton title={intl.formatMessage(messages.authorize)} icon='check' onClick={onAuthorize} /></div>
          <div className='account--panel__button'><IconButton title={intl.formatMessage(messages.reject)} icon='times' onClick={onReject} /></div>
        </div>
      </div>
    );
  }

}

export default injectIntl(AccountAuthorize);
