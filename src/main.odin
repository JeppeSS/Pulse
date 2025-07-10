package main

import "core:fmt"

import s "server"

main :: proc()
{
    p_broker := s.broker_create()
    defer s.broker_destroy( p_broker )

    for
    {
        s.broker_run( p_broker )

    }
    //p_server := s.server_create()
    //s.server_run( p_server )
    //defer s.server_destroy( p_server )
}