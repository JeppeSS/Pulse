package server

import "core:net"

Subscribe :: struct
{
    topic: string,
}


Unsubscribe :: struct
{
    topic: string,
}

Publish :: struct
{
    topic:   string,
    payload: [dynamic]u8
}


Shutdown :: struct
{

}

Message_Type :: enum u8
{
    Publish     = 1,
    Subscribe   = 2,
    Unsubscribe = 3
}


Message_Data :: union
{
    Subscribe,
    Unsubscribe,
    Publish,
    Shutdown
}

Message :: struct
{
    from: net.Endpoint,
    data: Message_Data
}