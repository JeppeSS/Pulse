package main

import "core:fmt"

import s "server"

main :: proc()
{
    p_connection_manager := s.connection_manager_create()
    defer s.connection_manager_destroy( p_connection_manager )

    p_broker := s.broker_create( p_connection_manager )
    defer s.broker_destroy( p_broker )

    for
    {
        s.broker_run( p_broker )
        s.connection_manager_run( p_connection_manager )
    }
}