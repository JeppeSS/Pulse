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

Unsubscribe_All :: struct
{

}

Publish :: struct
{
    topic:   string,
    payload: [dynamic]u8
}

Ping :: struct
{

}


Message_Type :: enum u8
{
    Publish     = 1,
    Subscribe   = 2,
    Unsubscribe = 3,
    Ping        = 4
}


Message_Data :: union
{
    Subscribe,
    Unsubscribe,
    Unsubscribe_All,
    Publish,
    Ping
}

Message :: struct
{
    from: net.Endpoint,
    data: Message_Data
}