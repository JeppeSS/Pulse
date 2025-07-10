package server

import "core:unicode"
import "core:net"
import "core:time"

Connect_Message :: struct
{
    endpoint: net.Endpoint,
    timestamp: time.Time
}

Disconnect_Message :: struct
{
    endpoint: net.Endpoint
}

Touch_Message :: struct
{
    endpoint: net.Endpoint
}

Connection_Message :: union
{
    Connect_Message,
    Disconnect_Message,
    Touch_Message
}