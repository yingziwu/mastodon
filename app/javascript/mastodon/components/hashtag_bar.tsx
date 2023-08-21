import { useState, useCallback } from 'react';

import { FormattedMessage } from 'react-intl';

import { Link } from 'react-router-dom';

import type { List, Record } from 'immutable';

import { groupBy, minBy } from 'lodash';

import { getStatusContent } from './status_content';

// About two lines on desktop
const VISIBLE_HASHTAGS = 7;

// Those types are not correct, they need to be replaced once this part of the state is typed
export type TagLike = Record<{ name: string }>;
export type StatusLike = Record<{
  tags: List<TagLike>;
  contentHTML: string;
  media_attachments: List<unknown>;
  spoiler_text?: string;
}>;

function normalizeHashtag(hashtag: string) {
  if (hashtag && hashtag.startsWith('#')) return hashtag.slice(1);
  else return hashtag;
}

function isNodeLinkHashtag(element: Node): element is HTMLLinkElement {
  return (
    element instanceof HTMLAnchorElement &&
    // it may be a <a> starting with a hashtag
    (element.textContent?.[0] === '#' ||
      // or a #<a>
      element.previousSibling?.textContent?.[
        element.previousSibling.textContent.length - 1
      ] === '#')
  );
}

/**
 * Removes duplicates from an hashtag list, case-insensitive, keeping only the best one
 * "Best" here is defined by the one with the more casing difference (ie, the most camel-cased one)
 * @param hashtags The list of hashtags
 * @returns The input hashtags, but with only 1 occurence of each (case-insensitive)
 */
function uniqueHashtagsWithCaseHandling(hashtags: string[]) {
  const groups = groupBy(hashtags, (tag) =>
    tag.normalize('NFKD').toLowerCase(),
  );

  return Object.values(groups).map((tags) => {
    if (tags.length === 1) return tags[0];

    // The best match is the one where we have the less difference between upper and lower case letter count
    const best = minBy(tags, (tag) => {
      const upperCase = Array.from(tag).reduce(
        (acc, char) => (acc += char.toUpperCase() === char ? 1 : 0),
        0,
      );

      const lowerCase = tag.length - upperCase;

      return Math.abs(lowerCase - upperCase);
    });

    return best ?? tags[0];
  });
}

// Create the collator once, this is much more efficient
const collator = new Intl.Collator(undefined, { sensitivity: 'accent' });
function localeAwareInclude(collection: string[], value: string) {
  return collection.find((item) => collator.compare(item, value) === 0);
}

// We use an intermediate function here to make it easier to test
export function computeHashtagBarForStatus(status: StatusLike): {
  statusContentProps: { statusContent: string };
  hashtagsInBar: string[];
} {
  let statusContent = getStatusContent(status);

  const tagNames = status
    .get('tags')
    .map((tag) => tag.get('name'))
    .toJS();

  // this is returned if we stop the processing early, it does not change what is displayed
  const defaultResult = {
    statusContentProps: { statusContent },
    hashtagsInBar: [],
  };

  // return early if this status does not have any tags
  if (tagNames.length === 0) return defaultResult;

  const template = document.createElement('template');
  template.innerHTML = statusContent.trim();

  const lastChild = template.content.lastChild;

  if (!lastChild) return defaultResult;

  template.content.removeChild(lastChild);
  const contentWithoutLastLine = template;

  // First, try to parse
  const contentHashtags = Array.from(
    contentWithoutLastLine.content.querySelectorAll<HTMLLinkElement>('a[href]'),
  ).reduce<string[]>((result, link) => {
    if (isNodeLinkHashtag(link)) {
      if (link.textContent) result.push(normalizeHashtag(link.textContent));
    }
    return result;
  }, []);

  // Now we parse the last line, and try to see if it only contains hashtags
  const lastLineHashtags: string[] = [];
  // try to see if the last line is only hashtags
  let onlyHashtags = true;

  Array.from(lastChild.childNodes).forEach((node) => {
    if (isNodeLinkHashtag(node) && node.textContent) {
      const normalized = normalizeHashtag(node.textContent);

      if (!localeAwareInclude(tagNames, normalized)) {
        // stop here, this is not a real hashtag, so consider it as text
        onlyHashtags = false;
        return;
      }

      if (!localeAwareInclude(contentHashtags, normalized))
        // only add it if it does not appear in the rest of the content
        lastLineHashtags.push(normalized);
    } else if (node.nodeType !== Node.TEXT_NODE || node.nodeValue?.trim()) {
      // not a space
      onlyHashtags = false;
    }
  });

  const hashtagsInBar = tagNames.filter(
    (tag) =>
      // the tag does not appear at all in the status content, it is an out-of-band tag
      !localeAwareInclude(contentHashtags, tag) &&
      !localeAwareInclude(lastLineHashtags, tag),
  );

  const isOnlyOneLine = contentWithoutLastLine.content.childElementCount === 0;
  const hasMedia = status.get('media_attachments').size > 0;
  const hasSpoiler = !!status.get('spoiler_text');

  // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition -- due to https://github.com/microsoft/TypeScript/issues/9998
  if (onlyHashtags && ((hasMedia && !hasSpoiler) || !isOnlyOneLine)) {
    // if the last line only contains hashtags, and we either:
    // - have other content in the status
    // - dont have other content, but a media and no CW. If it has a CW, then we do not remove the content to avoid having an empty content behind the CW button
    statusContent = contentWithoutLastLine.innerHTML;
    // and add the tags to the bar
    hashtagsInBar.push(...lastLineHashtags);
  }

  return {
    statusContentProps: { statusContent },
    hashtagsInBar: uniqueHashtagsWithCaseHandling(hashtagsInBar),
  };
}

/**
 *  This function will process a status to, at the same time (avoiding parsing it twice):
 * - build the HashtagBar for this status
 * - remove the last-line hashtags from the status content
 * @param status The status to process
 * @returns Props to be passed to the <StatusContent> component, and the hashtagBar to render
 */
export function getHashtagBarForStatus(status: StatusLike) {
  const { statusContentProps, hashtagsInBar } =
    computeHashtagBarForStatus(status);

  return {
    statusContentProps,
    hashtagBar: <HashtagBar hashtags={hashtagsInBar} />,
  };
}

const HashtagBar: React.FC<{
  hashtags: string[];
}> = ({ hashtags }) => {
  const [expanded, setExpanded] = useState(false);
  const handleClick = useCallback(() => {
    setExpanded(true);
  }, []);

  if (hashtags.length === 0) {
    return null;
  }

  const revealedHashtags = expanded
    ? hashtags
    : hashtags.slice(0, VISIBLE_HASHTAGS - 1);

  return (
    <div className='hashtag-bar'>
      {revealedHashtags.map((hashtag) => (
        <Link key={hashtag} to={`/tags/${hashtag}`}>
          #{hashtag}
        </Link>
      ))}

      {!expanded && hashtags.length > VISIBLE_HASHTAGS && (
        <button className='link-button' onClick={handleClick}>
          <FormattedMessage
            id='hashtags.and_other'
            defaultMessage='…and {count, plural, other {# more}}'
            values={{ count: hashtags.length - VISIBLE_HASHTAGS }}
          />
        </button>
      )}
    </div>
  );
};
