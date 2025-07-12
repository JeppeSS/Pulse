package config

import "core:time"
import "core:os"
import "core:strings"
import "core:strconv"
import "core:net"

Pulse_Config :: struct {
    ip: net.Address,
    port: int,
    connection_timeout: time.Duration,
    tick_interval: time.Duration,
}


parse_config_from_args :: proc() -> Pulse_Config 
{

    config := Pulse_Config{
        ip                 = net.IP4_Any,
        port               = 3030,
        connection_timeout = time.Second * 30,
        tick_interval      = time.Second * 5,
    }

    for i := 0; i < len( os.args ); i += 1
    {
        arg := os.args[ i ]

        if strings.has_prefix( arg, "-ip" ) && i+1 < len( os.args ) 
        {
            ip := os.args[ i+1 ]
            config.ip = net.parse_address( ip )
            i += 1
        }

        if strings.has_prefix( arg, "-port" ) && i+1 < len( os.args )
        {
            port_val := strconv.atoi( os.args[ i+1 ] )
            i += 1
            config.port = port_val
        }

        if strings.has_prefix( arg, "-timeout" ) && i+1 < len( os.args ) 
        {
            dur := cast( time.Duration )strconv.atoi( os.args[i+1] )
            i += 1
            config.connection_timeout = dur
        }

        if strings.has_prefix( arg, "-tick" ) && i+1 < len( os.args )
        {
            dur := cast( time.Duration )strconv.atoi( os.args[i+1] )
            i += 1
            config.tick_interval = dur
        }
    }

    if ip_str := os.get_env("PULSE_IP"); ip_str != "" 
    {
        config.ip = net.parse_address( ip_str )
    }

    if port_str := os.get_env( "PULSE_PORT" ); port_str != ""
    {
        port_val := strconv.atoi( port_str )
        config.port = port_val 
    }

    if timeout_str := os.get_env( "PULSE_TIMEOUT" ); timeout_str != "" 
    {
        dur := cast( time.Duration )strconv.atoi(timeout_str)
        config.connection_timeout = dur
    }

    if tick_str := os.get_env( "PULSE_TICK" ); tick_str != ""
     {
        dur := cast( time.Duration )strconv.atoi( tick_str )
        config.tick_interval = dur
    }

    return config
}