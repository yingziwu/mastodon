import { Map as ImmutableMap, List as ImmutableList, OrderedSet as ImmutableOrderedSet, fromJS } from 'immutable';

import {
  COMPOSE_MENTION,
  COMPOSE_REPLY,
  COMPOSE_DIRECT,
} from '../actions/compose';
import {
  SEARCH_CHANGE,
  SEARCH_CLEAR,
  SEARCH_FETCH_REQUEST,
  SEARCH_FETCH_FAIL,
  SEARCH_FETCH_SUCCESS,
  SEARCH_SHOW,
  SEARCH_EXPAND_SUCCESS,
  SEARCH_RESULT_CLICK,
  SEARCH_RESULT_FORGET,
} from '../actions/search';

const initialState = ImmutableMap({
  value: '',
  submitted: false,
  hidden: false,
  results: ImmutableMap(),
  isLoading: false,
  searchTerm: '',
  recent: ImmutableOrderedSet(),
});

export default function search(state = initialState, action) {
  switch(action.type) {
  case SEARCH_CHANGE:
    return state.set('value', action.value);
  case SEARCH_CLEAR:
    return state.withMutations(map => {
      map.set('value', '');
      map.set('results', ImmutableMap());
      map.set('submitted', false);
      map.set('hidden', false);
    });
  case SEARCH_SHOW:
    return state.set('hidden', false);
  case COMPOSE_REPLY:
  case COMPOSE_MENTION:
  case COMPOSE_DIRECT:
    return state.set('hidden', true);
  case SEARCH_FETCH_REQUEST:
    return state.withMutations(map => {
      map.set('isLoading', true);
      map.set('submitted', true);
    });
  case SEARCH_FETCH_FAIL:
    return state.set('isLoading', false);
  case SEARCH_FETCH_SUCCESS:
    return state.withMutations(map => {
      map.set('results', ImmutableMap({
        accounts: ImmutableList(action.results.accounts.map(item => item.id)),
        statuses: ImmutableList(action.results.statuses.map(item => item.id)),
        hashtags: fromJS(action.results.hashtags),
      }));

      map.set('searchTerm', action.searchTerm);
      map.set('isLoading', false);
    });
  case SEARCH_EXPAND_SUCCESS:
    const results = action.searchType === 'hashtags' ? fromJS(action.results.hashtags) : action.results[action.searchType].map(item => item.id);
    return state.updateIn(['results', action.searchType], list => list.concat(results));
  case SEARCH_RESULT_CLICK:
    return state.update('recent', set => set.add(fromJS(action.result)));
  case SEARCH_RESULT_FORGET:
    return state.update('recent', set => set.filterNot(result => result.get('q') === action.q));
  default:
    return state;
  }
}
