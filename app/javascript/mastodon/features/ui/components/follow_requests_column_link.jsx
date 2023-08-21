import PropTypes from 'prop-types';
import { Component } from 'react';

import { injectIntl, defineMessages } from 'react-intl';

import { List as ImmutableList } from 'immutable';
import { connect } from 'react-redux';

import { fetchFollowRequests } from 'mastodon/actions/accounts';
import { IconWithBadge } from 'mastodon/components/icon_with_badge';
import ColumnLink from 'mastodon/features/ui/components/column_link';

const messages = defineMessages({
  text: { id: 'navigation_bar.follow_requests', defaultMessage: 'Follow requests' },
});

const mapStateToProps = state => ({
  count: state.getIn(['user_lists', 'follow_requests', 'items'], ImmutableList()).size,
});

class FollowRequestsColumnLink extends Component {

  static propTypes = {
    dispatch: PropTypes.func.isRequired,
    count: PropTypes.number.isRequired,
    intl: PropTypes.object.isRequired,
  };

  componentDidMount () {
    const { dispatch } = this.props;

    dispatch(fetchFollowRequests());
  }

  render () {
    const { count, intl } = this.props;

    if (count === 0) {
      return null;
    }

    return (
      <ColumnLink
        transparent
        to='/follow_requests'
        icon={<IconWithBadge className='column-link__icon' id='user-plus' count={count} />}
        text={intl.formatMessage(messages.text)}
      />
    );
  }

}

export default injectIntl(connect(mapStateToProps)(FollowRequestsColumnLink));
