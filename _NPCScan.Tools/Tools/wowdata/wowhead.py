# -*- coding: utf_8 -*-
"""Shared routines to query Wowhead for game data."""

import contextlib
import math
import re
import urllib2

import BeautifulSoup
import PyV8

__author__ = 'Saiket'
__email__ = 'saiket.wow@gmail.com'
__license__ = 'LGPL'

_LOCALE_SUBDOMAINS = {  # Subdomains for localized Wowhead.com data
	'deDE': 'de',
	'enEU': 'www',
	'enUS': 'www',
	'esES': 'es',
	'esMX': 'es',
	'frFR': 'fr',
	'ptBR': 'pt',
	'ptPT': 'pt',
	'ruRU': 'ru',
}
_NPC_LEVEL_MIN = 0  # Querying level 0 returns mobs without a listed level
_NPC_LEVEL_MAX = 85 + 3  # Max rare mob level (+3 for boss level)
_NPC_LEVEL_UNKNOWN = 9999  # Sentinel value used for level "??"

class InvalidResultError(Exception):
  """Used when a requested web page can't be parsed properly."""
  pass

class EmptyResultError(Exception):
  """Used by `getSearchListview` when no results match a filter."""
  pass

class TruncatedResultsError(Exception):
  """Used when a listview query returns too many results.
  
  `args` attribute contains number of results total and returned.
  """
  pass


class _WH(PyV8.JSClass):
  """Wowhead JS utility function library stubs."""
  def sprintf(self, *args):
    """Joins printf arguments so they can easily be split later."""
    return '[' + ','.join(map(unicode, args)) + ']';


class _LANG(PyV8.JSClass):
  """Simulates Wowhead's localization constant lookup table by returning key names."""
  def __getattr__(self, name):
    """Identity function that returns the localization constant's name."""
    try:
      return super(_LANG, self).__getattr__(name)
    except AttributeError:
      return '{LANG.%s}' % name


class _Globals(PyV8.JSClass):
  """JS global scope with simulated Wowhead APIs to intercept listview data."""
  LANG = _LANG()

  def __init__(self):
    self._listviews = {}

  def Listview(self, data):
    """Impersonates Wowhead's JS Listview constructor."""
    self._listviews[data['id']] = data
setattr(_Globals, '$WH', _WH())


def getPage(locale, query):
  """Returns a BeautifulSoup object for `query` from Wowhead's `locale` subdomain."""
  try:
    subdomain = _LOCALE_SUBDOMAINS[locale]
  except KeyError:
    raise ValueError('Unsupported locale code %r.' % locale)
  request = urllib2.Request('http://%s.wowhead.com/%s' % (subdomain, query), unverifiable=True)
  with contextlib.closing(urllib2.urlopen(request)) as response:
    return BeautifulSoup.BeautifulSoup(response.read(), fromEncoding=response.info().getparam('charset'))


def getSearchListview(type, locale, **filters):
  """Returns listview data of the given search from Wowhead.

  Keyword arguments are used as filter parameters in search query.
  """
  query = '%s?filter=%s' % (type, ';'.join('%s=%s' % item for item in filters.iteritems()))
  page = getPage(locale, query)
  div = page.find('div', id='lv-' + type)
  if div is None:
    raise EmptyResultError()
  try:
    script = div.findNextSibling('script', type='text/javascript').getText()
  except AttributeError:
    raise InvalidResultError('%r listview script not found for query %r.' % (type, query))

  # Run JS source and intercept Listview definitions
  with PyV8.JSContext(_Globals()) as context:
    context.eval(script.encode('utf_8'))
    listviews = context.locals._listviews

  if type not in listviews:
    raise InvalidResultError('%r listview not initialized for query %r.' % (type, query))
  elif '_errors' in listviews[type]:
    raise InvalidResultError('Invalid %r query filter %r.' % (type, query))
  elif '_truncated' in listviews[type]:
    note = listviews[type]['note'].decode('utf_8')
    match = re.search(r'\[\{LANG\.lvnote_' + re.escape(type) + 'found\},(?P<total>\d+),(?P<displayed>\d+)\]', note)
    if match is None:
      raise InvalidResultError('Result total not found in view note %r.' % note)
    raise TruncatedResultsError(int(match.group('total')), int(match.group('displayed')))
  return listviews[type]


def getSearchResults(type, locale, **filters):
  """Returns a dict of IDs to result rows returned by `getSearchListview`."""
  try:
    return {result['id']: result
      for result in getSearchListview(type, locale, **filters)['data']}
  except EmptyResultError:
    return {}


def getNPCsByLevel(locale, minle, maxle, **filters):
  """Queries `getSearchResults` for NPCs by level, subdividing between `minle` and `maxle` if necessary."""
  try:
    return getSearchResults('npcs', locale, minle=minle, maxle=maxle, **filters)
  except TruncatedResultsError:
    if minle >= maxle:
      raise InvalidResultError('Too many level %d NPC results; Cannot subdivide further.' % minle)
    mid = math.floor((minle + maxle) / 2)
    npcs = getNPCsByLevel(locale, minle=minle, maxle=mid, **filters)
    npcs.update(getNPCsByLevel(locale, minle=mid + 1, maxle=maxle, **filters))
    return npcs


def getNPCsAllLevels(locale, **filters):
  """Queries `getNPCsByLevel` for NPCs of all levels."""
  npcs = getNPCsByLevel(locale, minle=_NPC_LEVEL_MIN, maxle=_NPC_LEVEL_MAX, **filters)
  npcs.update(getNPCsByLevel(locale, minle=_NPC_LEVEL_UNKNOWN, maxle=_NPC_LEVEL_UNKNOWN, **filters))
  return npcs