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

Tick_Message :: struct
{

}

Connection_Message :: union
{
    Connect_Message,
    Disconnect_Message,
    Touch_Message,
    Tick_Message
}