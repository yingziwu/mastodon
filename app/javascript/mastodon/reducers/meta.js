import { Map as ImmutableMap } from 'immutable';

import { changeLayout } from 'mastodon/actions/app';
import { STORE_HYDRATE } from 'mastodon/actions/store';
import { layoutFromWindow } from 'mastodon/is_mobile';

const initialState = ImmutableMap({
  streaming_api_base_url: null,
  access_token: null,
  layout: layoutFromWindow(),
  permissions: '0',
});

export default function meta(state = initialState, action) {
  switch(action.type) {
  case STORE_HYDRATE:
    return state.merge(action.state.get('meta')).set('permissions', action.state.getIn(['role', 'permissions']));
  case changeLayout.type:
    return state.set('layout', action.payload.layout);
  default:
    return state;
  }
}
