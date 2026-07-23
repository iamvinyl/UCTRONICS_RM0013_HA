#!/usr/bin/with-contenv bashio

bashio::log.info "Starting UCTRONICS RM0004 display"

if [[ ! -e /dev/i2c-1 ]]; then
    bashio::log.fatal "I2C device /dev/i2c-1 was not found."
    exit 1
fi

cd /lcd_display/ || exit 1

bashio::log.info "Building the LCD display program"
make clean
make

display_args=()

if bashio::config.true 'show_home_assistant_logo'; then
    display_args+=("--logo")
fi

if bashio::config.true 'show_ip_address'; then
    display_args+=("--ip")
fi

if bashio::config.true 'show_cpu_usage'; then
    display_args+=("--cpu")
fi

if bashio::config.true 'show_ram_usage'; then
    display_args+=("--ram")
fi

if bashio::config.true 'show_disk_space'; then
    display_args+=("--disk")
fi

screen_duration="$(bashio::config 'screen_duration')"

if [[ ${#display_args[@]} -eq 0 ]]; then
    bashio::log.warning \
        "No display screens are enabled. Falling back to the Home Assistant logo."
    display_args+=("--logo")
fi

bashio::log.info "Enabled display arguments: ${display_args[*]}"
bashio::log.info "Screen duration: ${screen_duration} seconds"

exec ./display "${display_args[@]}" --duration "${screen_duration}"
