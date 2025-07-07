package main

import "core:fmt"

import s "server"

main :: proc()
{
    p_server := s.server_create()
    s.server_run( p_server )
    defer s.server_destroy( p_server )
}