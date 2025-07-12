package main

import "core:time"
import "core:log"

import s "server"
import q "server/queue"
import c "server/config"

main :: proc()
{
    log_options := log.Options{ .Level } | log.Full_Timestamp_Opts
    context.logger = log.create_console_logger ( opt = log_options )

    config := c.parse_config_from_args()


    p_connection_manager := s.connection_manager_create( config )
    defer s.connection_manager_destroy( p_connection_manager )

    p_broker := s.broker_create( p_connection_manager, config )
    defer s.broker_destroy( p_broker )


    // TODO[Jeppe]: Move to context manager
    p_connection_manager.p_broker = p_broker


    ticker: time.Stopwatch
    time.stopwatch_start( &ticker )

    ticker_interval := config.tick_interval

    log.info( "Starting Pulse Server..." )
    for
    {
        if time.stopwatch_duration( ticker ) > ticker_interval
        {
            q.enqueue(s.Connection_Message, &p_connection_manager.actor.inbox, s.Tick_Message{})
            time.stopwatch_reset( &ticker )
            time.stopwatch_start( &ticker )
        }
        s.broker_run( p_broker )
        s.connection_manager_run( p_connection_manager )

        time.sleep( time.Millisecond * 5 )
    }
}