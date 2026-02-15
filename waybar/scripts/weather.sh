#!/bin/bash

# Fetch weather data
DATA=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=1.3521&longitude=103.8198&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m&timezone=Asia%2FSingapore")

# Check if curl succeeded
if [ -z "$DATA" ]; then
  echo '{"text":"N/A","tooltip":"Failed to fetch weather"}'
  exit 0
fi

# Parse JSON
TEMP=$(echo "$DATA" | jq -r '.current.temperature_2m // "N/A"')
FEELS=$(echo "$DATA" | jq -r '.current.apparent_temperature // "N/A"')
HUMIDITY=$(echo "$DATA" | jq -r '.current.relative_humidity_2m // "N/A"')
CLOUD=$(echo "$DATA" | jq -r '.current.cloud_cover // "N/A"')
WIND=$(echo "$DATA" | jq -r '.current.wind_speed_10m // "N/A"')
WIND_DIR=$(echo "$DATA" | jq -r '.current.wind_direction_10m // "0"')
CODE=$(echo "$DATA" | jq -r '.current.weather_code // "0"')

# Get emoji and description based on weather code
case $CODE in
0)
  EMOJI="☀"
  DESC="Clear sky"
  ;;
1)
  EMOJI="🌤"
  DESC="Mainly clear"
  ;;
2)
  EMOJI="⛅"
  DESC="Partly cloudy"
  ;;
3)
  EMOJI="☁"
  DESC="Overcast"
  ;;
45 | 48)
  EMOJI="🌫"
  DESC="Foggy"
  ;;
51 | 53 | 55)
  EMOJI="🌦"
  DESC="Drizzle"
  ;;
61 | 63 | 65 | 80 | 81 | 82)
  EMOJI="🌧"
  DESC="Rainy"
  ;;
95 | 96 | 99)
  EMOJI="⛈"
  DESC="Thunderstorm"
  ;;
*)
  EMOJI="🌤"
  DESC="Unknown"
  ;;
esac

# Wind direction
DIR="N"
if [ "$WIND_DIR" != "N/A" ]; then
  if [ $WIND_DIR -ge 23 ] && [ $WIND_DIR -le 67 ]; then
    DIR="NE"
  elif [ $WIND_DIR -ge 68 ] && [ $WIND_DIR -le 112 ]; then
    DIR="E"
  elif [ $WIND_DIR -ge 113 ] && [ $WIND_DIR -le 157 ]; then
    DIR="SE"
  elif [ $WIND_DIR -ge 158 ] && [ $WIND_DIR -le 202 ]; then
    DIR="S"
  elif [ $WIND_DIR -ge 203 ] && [ $WIND_DIR -le 247 ]; then
    DIR="SW"
  elif [ $WIND_DIR -ge 248 ] && [ $WIND_DIR -le 292 ]; then
    DIR="W"
  elif [ $WIND_DIR -ge 293 ] && [ $WIND_DIR -le 337 ]; then
    DIR="NW"
  fi
fi

# Build tooltip text
TOOLTIP="Singapore Weather
$DESC
Temp: ${TEMP}C
Feels: ${FEELS}C
Humidity: ${HUMIDITY}%
Clouds: ${CLOUD}%
Wind: ${WIND} km/h $DIR"

# Output JSON using printf to avoid issues
printf '{"text":"%s %sC","tooltip":"%s"}\n' "$EMOJI" "$TEMP" "${TOOLTIP//$'\n'/\\n}"
