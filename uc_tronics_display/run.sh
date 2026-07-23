#!/usr/bin/with-contenv bashio

bashio::log.info "Starting UCTRONICS RM0013 160x80 color display v1.2.4"

if [[ ! -e /dev/i2c-1 ]]; then
    bashio::log.fatal "I2C device /dev/i2c-1 was not found."
    exit 1
fi

cd /lcd_display/ || exit 1

bashio::log.info "Building the LCD display program"
make clean

if ! make; then
    bashio::log.fatal "The LCD display program failed to compile."
    exit 1
fi

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

#
# Read the primary Home Assistant host interface from Supervisor.
# This avoids showing the add-on container's 172.30.x.x address.
#
host_ip_cidr="$(
    bashio::network.ipv4_address default 2>/dev/null |
    head -n 1 ||
    true
)"
host_ip="${host_ip_cidr%%/*}"

if [[ ! "${host_ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    bashio::log.warning \
        "Supervisor did not return a usable host IPv4 address."
    host_ip="Unavailable"
fi

#
# Read Home Assistant host disk usage from Supervisor rather than the
# add-on container overlay filesystem.
#
disk_total="$(bashio::host.disk_total 2>/dev/null || true)"
disk_used="$(bashio::host.disk_used 2>/dev/null || true)"
disk_percent=0

if \
    [[ "${disk_total}" =~ ^[0-9]+([.][0-9]+)?$ ]] &&
    [[ "${disk_used}" =~ ^[0-9]+([.][0-9]+)?$ ]]
then
    disk_percent="$(
        awk \
            -v used="${disk_used}" \
            -v total="${disk_total}" \
            'BEGIN {
                if (total > 0) {
                    value = (used / total) * 100;
                    if (value < 0) value = 0;
                    if (value > 100) value = 100;
                    printf "%.0f", value;
                } else {
                    print 0;
                }
            }'
    )"
else
    bashio::log.warning \
        "Supervisor did not return usable host disk information."
fi

bashio::log.info "Enabled display arguments: ${display_args[*]}"
bashio::log.info "Screen duration: ${screen_duration} seconds"
bashio::log.info "Home Assistant host IP: ${host_ip}"
bashio::log.info "Home Assistant host disk usage: ${disk_percent}%"

exec ./display \
    "${display_args[@]}" \
    --duration "${screen_duration}" \
    --host-ip "${host_ip}" \
    --disk-percent "${disk_percent}"
