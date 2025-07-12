package config

import "core:time"
import "core:os"
import "core:strings"
import "core:strconv"

Pulse_Config :: struct {
    port: int,
    connection_timeout: time.Duration,
    tick_interval: time.Duration,
}


parse_config_from_args :: proc() -> Pulse_Config 
{

    config := Pulse_Config{
        port = 3030,
        connection_timeout = time.Second * 30,
        tick_interval = time.Second * 5,
    }

    for i := 0; i < len( os.args ); i += 1
    {
        arg := os.args[ i ]

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