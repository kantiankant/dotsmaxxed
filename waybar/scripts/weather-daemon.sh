#!/bin/bash

CACHE_FILE="/tmp/waybar_weather_cache"
UPDATE_INTERVAL=60

# Function to fetch and cache weather
fetch_and_cache() {
  DATA=$(curl -s --max-time 3 "https://api.open-meteo.com/v1/forecast?latitude=1.3521&longitude=103.8198&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m&timezone=Asia%2FSingapore")

  if [ -z "$DATA" ]; then
    return 1
  fi

  TEMP=$(echo "$DATA" | jq -r '.current.temperature_2m // "N/A"')
  FEELS=$(echo "$DATA" | jq -r '.current.apparent_temperature // "N/A"')
  HUMIDITY=$(echo "$DATA" | jq -r '.current.relative_humidity_2m // "N/A"')
  CLOUD=$(echo "$DATA" | jq -r '.current.cloud_cover // "N/A"')
  WIND=$(echo "$DATA" | jq -r '.current.wind_speed_10m // "N/A"')
  WIND_DIR=$(echo "$DATA" | jq -r '.current.wind_direction_10m // "0"')
  CODE=$(echo "$DATA" | jq -r '.current.weather_code // "0"')

  case $CODE in
  0) EMOJI="☀" ;;
  1 | 2) EMOJI="🌤" ;;
  3) EMOJI="☁" ;;
  45 | 48) EMOJI="🌫" ;;
  51 | 53 | 55 | 61 | 63 | 65 | 80 | 81 | 82) EMOJI="🌧" ;;
  95 | 96 | 99) EMOJI="⛈" ;;
  *) EMOJI="🌤" ;;
  esac

  # Create JSON and save to cache
  printf '{"text":"%s %s°C","tooltip":"Singapore Weather\\nTemp: %s°C\\nFeels: %s°C\\nHumidity: %s%%"}\n' \
    "$EMOJI" "$TEMP" "$TEMP" "$FEELS" "$HUMIDITY" >"$CACHE_FILE"
}

# Initial fetch
fetch_and_cache

# Keep updating in background
while true; do
  sleep $UPDATE_INTERVAL
  fetch_and_cache
done
