import os
import re
import requests
import json
from datetime import datetime

RTT_BASE_URL = "https://data.rtt.io"
# pin the API version so future RTT changes don't silently break the display
RTT_API_VERSION = "2026-07-25"

# if config.json holds a refresh token, the short life access token issued for it is cached here
cachedAccessToken = None

def abbrStation(journeyConfig, inputStr):
    dict = journeyConfig['stationAbbr']
    for key in dict.keys():
        inputStr = inputStr.replace(key, dict[key])
    return inputStr

def cleanToken(token):
    token = token.strip()
    if token.lower().startswith('bearer '):
        token = token[7:].strip()
    return token

def rttRequest(token, url):
    headers = {'Authorization': f"Bearer {token}", 'Version': RTT_API_VERSION}
    return requests.get(url, headers=headers)

def requestAccessToken(refreshToken):
    global cachedAccessToken
    response = rttRequest(refreshToken, f"{RTT_BASE_URL}/api/get_access_token")
    if response.status_code != 200:
        return False
    cachedAccessToken = response.json()['token']
    return True

def rttGet(token, url):
    token = cleanToken(token)
    response = rttRequest(cachedAccessToken or token, url)
    # the token may be a refresh token or the cached access token may have expired,
    # so swap the configured token for a new access token and try again
    if response.status_code == 401 and requestAccessToken(token):
        response = rttRequest(cachedAccessToken, url)
    if response.status_code == 401:
        raise ValueError(f"RTT API rejected the token in config.json (401): {response.text}")
    if response.status_code == 429:
        raise ValueError(f"RTT rate limit hit, retry after {response.headers.get('Retry-After')}s")
    response.raise_for_status()
    # 204 = valid query but no services, there is no body
    if response.status_code == 204:
        return None
    return response.json()

def formatTime(isoTime):
    # times are now ISO 8601 datetimes rather than "HHMM", convert to local time for display
    # parsed with strptime rather than fromisoformat so it still works on Python 3.6
    match = re.match(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?$', isoTime)
    if match is None:
        return isoTime[11:16]
    dateTime, offset = match.groups()
    # no offset means the time is already local to the station
    if offset is None:
        return dateTime[11:16]
    offset = '+0000' if offset == 'Z' else offset.replace(':', '')
    return datetime.strptime(dateTime + offset, '%Y-%m-%dT%H:%M:%S%z').astimezone().strftime('%H:%M')

def loadDeparturesForStationRTT(journeyConfig, token):
    if journeyConfig["departureStation"] == "":
        raise ValueError(
            "Please set the journey.departureStation property in config.json")

    if cleanToken(token) == "":
        raise ValueError(
            "Please complete the rttApi section of your config.json file")

    departureStation = journeyConfig["departureStation"]

    url = f"{RTT_BASE_URL}/gb-nr/location?code={departureStation}"
    if journeyConfig.get("destinationStation"):
        url += f"&filterTo={journeyConfig['destinationStation']}"

    data = rttGet(token, url)
    translated_departures = []

    if data is None or not data.get('services'):
        return translated_departures, departureStation

    for item in data['services']:
        temporal = item.get('temporalData') or {}
        departure = temporal.get('departure') or {}
        metadata = item['scheduleMetadata']

        # skip passing trains, trains terminating here and non-passenger moves
        if temporal.get('displayAs') in (None, 'PASS') or 'scheduleAdvertised' not in departure:
            continue
        if not metadata.get('inPassengerService', True):
            continue

        uid = metadata['identity']
        destination_name = item['destination'][0]['location']['description']

        dt = departure['scheduleAdvertised']
        edt = departure.get('realtimeActual') or departure.get('realtimeForecast') or departure.get('realtimeEstimate') or dt

        status = temporal['displayAs']
        if departure.get('isCancelled'):
            status = 'CANCELLED'

        mode = 'bus' if 'BUS' in metadata.get('modeType', 'TRAIN') else 'train'

        platformData = (item.get('locationMetadata') or {}).get('platform') or {}
        platform = platformData.get('actual') or platformData.get('planned') or ""

        translated_departures.append({'uid': uid, 'destination_name': abbrStation(journeyConfig, destination_name), 'aimed_departure_time': formatTime(dt),
                                        'expected_departure_time': formatTime(edt),
                                        'status': status, 'mode': mode, 'platform': platform,
                                        'time_table_url': f"{RTT_BASE_URL}/gb-nr/service?identity={uid}&departureDate={metadata['departureDate']}"})

        if len(translated_departures) == 5:
            break

    return translated_departures, departureStation

def loadDestinationsForDepartureRTT(journeyConfig, token, timetableUrl):
    calling_data = rttGet(token, timetableUrl)
    locations = calling_data['service']['locations']

    index = 0
    for loc in locations:
        if journeyConfig["departureStation"] in loc['location'].get('shortCodes', []):
            break
        index += 1

    calling_at = []
    for loc in locations[index+1:]:
        # the service now lists every timing point, only show public stops
        if loc['temporalData'].get('displayAs') not in ('CALL', 'TERMINATES'):
            continue
        callType = loc['temporalData'].get('realtimeCallType') or loc['temporalData'].get('scheduledCallType') or ''
        if not callType.startswith('ADVERTISED'):
            continue
        calling_at.append(abbrStation(journeyConfig, loc['location']['description']))

    if len(calling_at) == 1:
        calling_at[0] = calling_at[0] + ' only.'

    return calling_at

def loadDeparturesForStation(journeyConfig, appId, apiKey):
    if journeyConfig["departureStation"] == "":
        raise ValueError(
            "Please set the journey.departureStation property in config.json")

    if appId == "" or apiKey == "":
        raise ValueError(
            "Please complete the transportApi section of your config.json file")

    departureStation = journeyConfig["departureStation"]

    URL = f"http://transportapi.com/v3/uk/train/station/{departureStation}/live.json"

    PARAMS = {'app_id': appId,
              'app_key': apiKey,
              'calling_at': journeyConfig["destinationStation"]}

    r = requests.get(url=URL, params=PARAMS)

    data = r.json()
    #apply abbreviations / replacements to station names (long stations names dont look great on layout)
    #see config file for replacement list 
    for item in data["departures"]["all"]:
         item['origin_name'] = abbrStation(journeyConfig, item['origin_name'])
         item['destination_name'] = abbrStation(journeyConfig, item['destination_name'])

    if "error" in data:
        raise ValueError(data["error"])

    return data["departures"]["all"], data["station_name"]


def loadDestinationsForDeparture(journeyConfig, timetableUrl):
    r = requests.get(url=timetableUrl)

    data = r.json()

    #apply abbreviations / replacements to station names (long stations names dont look great on layout)
    #see config file for replacement list
    foundDepartureStation = False

    for item in list(data["stops"]):
        if item['station_code'] == journeyConfig['departureStation']:
            foundDepartureStation = True

        if foundDepartureStation == False:
            data["stops"].remove(item)
            continue

        item['station_name'] = abbrStation(journeyConfig, item['station_name'])

    if "error" in data:
        raise ValueError(data["error"])

    departureDestinationList = list(map(lambda x: x["station_name"], data["stops"]))[1:]

    if len(departureDestinationList) == 1:
        departureDestinationList[0] = departureDestinationList[0] + ' only.'

    return departureDestinationList

