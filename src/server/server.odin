package server

import "core:net"
import "core:fmt"
import "core:strings"

import p "protocol"


Server_Config :: struct
{

}

Server :: struct
{
    config: Server_Config,
    socket: net.UDP_Socket,

    topic_map: map[string][dynamic]net.Endpoint
}


server_create :: proc() -> ^Server
{
    p_server := new( Server )

    // TODO[Jeppe]: Move to server config
    socket, err := net.make_bound_udp_socket( net.IP4_Loopback, 3030 )
    if err != nil
    {
        fmt.eprintfln("Error: Could not create bound UDP socket: %v", err )
        free( p_server )
        return nil
    }

    p_server.socket = socket
    p_server.topic_map = make(map[string][dynamic]net.Endpoint)

    return p_server
}


server_run :: proc( p_server: ^Server )
{
    buffer: [4096]u8
    header_size := size_of( p.Message_Header )
    for
    {
        bytes_read, remote_endpoint, err := net.recv_udp( p_server.socket, buffer[:] )
        header, success := parse_message_header( buffer[:] )
        if !success
        {
            fmt.eprintfln("Error: malformed message header (bytes_read = %d)", bytes_read)
            continue
        }
        total_needed := header_size + int( header.topic_len ) + int( header.payload_len )
        if bytes_read < total_needed
        {
            fmt.eprintfln("Error: malformed message (bytes_read = %d)", bytes_read)
            continue
        }

        topic_start := header_size
        topic_end := topic_start + int( header.topic_len )
        topic := strings.clone( string( buffer[ topic_start : topic_end ] ) )
        defer delete( topic )

        payload_start: u16 = u16( topic_end )
        payload_end := payload_start + header.payload_len
        payload := buffer[ payload_start : payload_end ]

        if header.message_type == .Subscribe
        {
            handle_subscribe( p_server, topic, remote_endpoint )
        }
        else if header.message_type == .Publish
        {
            handle_publish( p_server, topic, payload )
        }
        else if header.message_type == .Unsubscribe
        {
            handle_unsubscribe( p_server, topic, remote_endpoint )
        }
    }
}


server_destroy :: proc( p_server: ^Server )
{
    for topics in p_server.topic_map
    {
        delete( topics )
    }
    delete( p_server.topic_map )
    free( p_server )
}


@(private)
handle_subscribe :: proc( p_server: ^Server, topic: string, client: net.Endpoint )
{
    subscribers, ok := p_server.topic_map[ topic ]
    found := false
    if ok
    {
        for subscriber in subscribers
        {
            if subscriber.address == client.address && subscriber.port == client.port
            {
                found = true
                break
            }
        }
    }
    else
    {
        p_server.topic_map[ topic ] = make( [dynamic]net.Endpoint, 0, 16 )
    }

    if !found
    {
        append( &p_server.topic_map[ topic ], client )
    }


    for topic, subs in p_server.topic_map 
    {
        fmt.printfln( "Topic '%s': %d subscriber(s)", topic, len( subs ) )
    }
}

@(private)
handle_publish :: proc( p_server: ^Server, publish_topic: string, payload: []u8 )
{

    total_sent := 0
    for subscribe_topic, subscribers in p_server.topic_map
    {
        if !topic_matches( subscribe_topic, publish_topic )
        {
            continue
        }

        for subscriber in subscribers
        {
            _, err := net.send_udp( p_server.socket, payload[:], subscriber )
            if err != nil
            {
                fmt.eprintfln("Failed to send to %v: %v", subscriber, err)
            }
            else
            {
                total_sent += 1
            }
        }
    }

    fmt.printfln("Published to %d subs matching topic '%s'", total_sent, publish_topic)
}

@(private)
handle_unsubscribe :: proc( p_server: ^Server, topic: string, client: net.Endpoint )
{
    subscribers, ok := p_server.topic_map[ topic ]
    if !ok
    {
        return
    }

    idx := 0
    for subscriber in subscribers
    {
        if subscriber.address == client.address && subscriber.port == client.port
        {
            unordered_remove( &p_server.topic_map[ topic ], idx )
            fmt.printfln( "Unsubscribed %v from topic '%s'", client, topic )
            break
        }

        idx += 1
    }

    if len( p_server.topic_map[ topic ] ) == 0 
    {
        delete( p_server.topic_map[ topic ] )
        fmt.printfln("Topic '%s' now has no subscribers; removed", topic)
    }
}


@(private)
parse_message_header :: proc( buffer: []u8 ) -> ( header: p.Message_Header, success: bool )
{
    if len( buffer) <= 0
    {
        return p.Message_Header{}, false
    }

    msg_type     := buffer[0];
    topic_len    := buffer[1];
    payload_len  := (u16(buffer[2]) << 8) | u16(buffer[3]);

    return p.Message_Header{
        message_type     = p.Message_Type(msg_type),
        topic_len    = topic_len,
        payload_len  = payload_len,
    }, true;
}

@(private)
topic_matches :: proc( sub: string, pub: string ) -> bool
{
    sub_parts := strings.split( sub, "/" )
    defer delete( sub_parts )
    
    pub_parts := strings.split( pub, "/" )
    defer delete( pub_parts )

    for i in 0..<len( sub_parts )
    {
        if i >= len( pub_parts )
        {
            return false
        }


        if sub_parts[ i ] == "#"
        {
            return true
        }
        else if sub_parts[ i ] == "+"
        {
            continue
        }
        else
        {
            if sub_parts[ i ] != pub_parts[ i ]
            {
                return false
            }
        }
    }

    return len( sub_parts ) == len( pub_parts )
}