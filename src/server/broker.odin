package server

import "core:mem"
import "core:net"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"


import q "queue"
import a "actor"


Topic_Info :: struct
{
    subscribers: [dynamic]net.Endpoint,
    retained:    [dynamic]u8
}


Broker :: struct
{
    using actor: a.Actor( Message ),
    socket: net.UDP_Socket,
    topic_map: map[string]Topic_Info,
    subscriptions: map[string][dynamic]string,
    p_manager: ^Connection_Manager
}


broker_create :: proc( p_manager: ^Connection_Manager ) -> ^Broker
{
    p_broker := new( Broker )
    q.queue_init( Message, &p_broker.inbox )

    p_broker.topic_map = make( map[string]Topic_Info )
    p_broker.subscriptions = make( map[string][dynamic]string )

    // TODO[Jeppe]: Move to config
    socket, err := net.make_bound_udp_socket( net.IP4_Any, 3030 )
    if err != nil
    {
        fmt.eprintfln( "Failed to create socket: %v", err )
        q.queue_destroy( Message, &p_broker.inbox )
        free( p_broker )
        return nil
    }

    err_block := net.set_blocking( socket, false )
    if err_block != .None
    {
        fmt.eprintfln( "Failed to set non-blocking: %v", err_block )
        net.close(socket)
        q.queue_destroy( Message, &p_broker.inbox )
        free( p_broker )
        return nil
    }

    p_broker.socket = socket
    p_broker.p_manager = p_manager

    return p_broker
}



broker_run :: proc( p_broker: ^Broker )
{
    broker_poll( p_broker )
    a.actor_run( Message, p_broker, broker_handle_message )
}


broker_destroy :: proc( p_broker: ^Broker )
{
    net.close( p_broker.socket )
    q.queue_destroy( Message, &p_broker.inbox )
    
    for sub_topic, sub_info in p_broker.topic_map
    {
        if sub_info.subscribers != nil
        {
            delete( sub_info.subscribers )
        }
        if sub_info.retained != nil
        {
            delete( sub_info.retained )
        } 
    }

    free( p_broker )
}


@(private)
broker_poll :: proc( p_broker: ^Broker )
{
    buffer: [4096]u8
    for
    {
        bytes_read, remote_endpoint, err := net.recv_udp( p_broker.socket, buffer[:] )
        if err != .None
        {
            if err == .Would_Block
            {
                return
            }
            fmt.eprintfln( "recv_udp error: %v", err )
            return
        }

        q.enqueue(Connection_Message, &p_broker.p_manager.actor.inbox, Touch_Message {
            endpoint = remote_endpoint
        })

        fmt.printfln( "Received UDP from %v, %d bytes", remote_endpoint, bytes_read )
        message, ok := decode_incoming_message( buffer[:], remote_endpoint )
        if ok
        {
            q.enqueue( Message, &p_broker.inbox, message )
        }
    }
}

@(private)
broker_handle_message :: proc( p_broker: ^Broker, message: Message )
{
    switch _ in message.data
    {
        case Subscribe: 
            fmt.printfln( "Handling Subscribe from %v", message.from )
            handle_subscribe( p_broker, message.from, message.data.(Subscribe) )
        case Unsubscribe: 
            fmt.printfln( "Handling Unsubscribe from %v", message.from )
            handle_unsubscribe( p_broker, message.from, message.data.(Unsubscribe) )
        case Publish:
            fmt.printfln( "Handling Publish from %v", message.from )
            handle_publish( p_broker, message.from, message.data.(Publish) )
        case Unsubscribe_All:
            fmt.printfln( "Handling Unsubscribe_All from %v", message.from )
            handle_unsubscribe_all( p_broker, message.from, message.data.(Unsubscribe_All) )
        case Ping: 
            fmt.printfln( "Handling Ping from %v", message.from )
            handle_ping( p_broker, message.from )
    }
}



@(private)
decode_incoming_message :: proc( buffer: []u8, from: net.Endpoint ) -> ( message: Message, success: bool )
{
    if len( buffer) <= 0
    {
        return Message{}, false
    }

    header_size := size_of( u8 ) + size_of( u8 ) + size_of( u16 )

    message_type := Message_Type( buffer[0] )
    topic_len    := buffer[1]
    payload_len  := ( u16(buffer[2]) << 8) | u16(buffer[3] )

    topic_start := header_size
    topic_end := topic_start + int( topic_len )
    topic := strings.clone( string( buffer[ topic_start : topic_end ] ) )

    payload_start: u16 = u16( topic_end )
    payload_end := payload_start + payload_len


    
    message_data: Message_Data
    switch message_type {
        case .Subscribe:
            message_data = Subscribe{ topic = topic }
        case .Unsubscribe:
            message_data = Unsubscribe{ topic = topic }
        case .Publish:
            cloned_payload := make([dynamic]u8, payload_len)
            copy(cloned_payload[:], buffer[payload_start : payload_end])

            message_data = Publish{
                topic = topic,
                payload = cloned_payload,
            }
        case .Ping:
            message_data = Ping{}
        case:
            fmt.eprintfln( "Unknown message_type: %d from %v", message_type, from )
            return Message{}, false
    }

    fmt.printfln( "Decoded %v message from %v", message_type, from )
    return Message{ from = from, data = message_data }, true
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

@(private)
handle_subscribe :: proc( p_broker: ^Broker, from: net.Endpoint, message: Subscribe )
{
    topic_info, ok := p_broker.topic_map[ message.topic ]
    if !ok
    {
        topic_info = Topic_Info{ 
            subscribers = make( [dynamic]net.Endpoint, 0, 8 )
        }
    }

    already_subscribed := false
    for sub in topic_info.subscribers
    {
        if sub.address == from.address && sub.port == from.port
        {
            already_subscribed = true
            break
        }
    }


    if !already_subscribed
    {
        append( &topic_info.subscribers, from )
    }

    
    p_broker.topic_map[message.topic] = topic_info

    key := net.endpoint_to_string( from )
    topics, exists := p_broker.subscriptions[ key ] 
    if !exists {
        topics = make( [dynamic]string, 0, 4 )
    }
    append( &topics, strings.clone( message.topic ) )
    p_broker.subscriptions[ key ] = topics

    fmt.printfln("Client %v subscribed to '%s'", from, message.topic)
    fmt.printfln("Topic '%s' now has %d subscriber(s)", message.topic, len(topic_info.subscribers))


   for topic_key, info in p_broker.topic_map
   {
        if topic_matches( message.topic, topic_key ) && info.retained != nil && len( info.retained ) > 0 
        {
            _, err := net.send_udp( p_broker.socket, info.retained[:], from )
            if err != nil 
            {
                fmt.eprintfln("Failed to send retained to %v on topic '%s': %v", from, topic_key, err)
            } 
            else 
            {
                fmt.printfln("Sent retained to %v on topic '%s'", from, topic_key)
            }
        }
    }

}

@(private)
handle_unsubscribe :: proc( p_broker: ^Broker, from: net.Endpoint, message: Unsubscribe )
{
    topic_info, ok := p_broker.topic_map[ message.topic ]
    if !ok
    {
        return
    }

    idx := 0
    found := false
    for subscriber in topic_info.subscribers
    {
        if subscriber.address == from.address && subscriber.port == from.port
        {
            found = true
            break
        }

        idx += 1
    }


    if found
    {
        unordered_remove( &topic_info.subscribers, idx )
        fmt.printfln("Client %v unsubscribed from '%s'", from, message.topic )
    }


    if len(topic_info.subscribers) == 0 
    {
        delete( topic_info.subscribers )

        if topic_info.retained == nil || len(topic_info.retained) == 0 
        {
            if topic_info.retained != nil 
            {
                delete( topic_info.retained )
            }
            delete_key( &p_broker.topic_map, message.topic )
            fmt.printfln("No more subscribers; removed topic '%s'", message.topic)
        }
        else
        {
            p_broker.topic_map[message.topic] = topic_info
        }
    }
    else
    {
        p_broker.topic_map[message.topic] = topic_info
    }



    key := net.endpoint_to_string( from )
    topics, exists := p_broker.subscriptions[ key ]
    if exists
    {
        idx := 0
        for t in topics
        {
            if t == message.topic 
            {
                unordered_remove( &topics, idx )
                break
            }
            idx += 1
        }

        if len( topics ) == 0
        {
            delete_key(&p_broker.subscriptions, key)
        }
        else
        {
            p_broker.subscriptions[key] = topics
        }
    }
}

@(private)
handle_publish :: proc( p_broker: ^Broker, from: net.Endpoint, message: Publish ) {
    defer delete( message.payload )
    total_sent := 0


    topic_info, ok :=  p_broker.topic_map[ message.topic ]
    if !ok
    {
        topic_info = Topic_Info{
            subscribers = make([dynamic]net.Endpoint, 0, 8),
        }
    }

    retained_copy := make( [dynamic]u8, len( message.payload ) )
    copy( retained_copy[:], message.payload[:] )
    topic_info.retained = retained_copy

    p_broker.topic_map[ message.topic ] = topic_info

     for sub_topic, sub_info in p_broker.topic_map
     {
        if !topic_matches(sub_topic, message.topic)
        {
            continue
        }

        for sub in sub_info.subscribers 
        {
            _, err := net.send_udp( p_broker.socket, message.payload[:], sub )
            if err != nil 
            {
                fmt.eprintfln( "Failed to send to %v: %v", sub, err )
            } 
            else 
            {
                total_sent += 1
            }
        }
    }


    fmt.printfln( "Published to %d subs matching topic '%s'", total_sent, message.topic )
}

@(private)
handle_unsubscribe_all :: proc( p_broker: ^Broker, from: net.Endpoint, message: Unsubscribe_All )
{
    key := net.endpoint_to_string( from )
    topics, exists := p_broker.subscriptions[ key ]
    if !exists 
    {
        return
    }

    for topic in topics 
    {
        q.enqueue(Message, &p_broker.inbox, Message{
            from = from,
            data = Unsubscribe{ topic = topic }
        })
    }
}

@(private)
handle_ping :: proc( p_broker: ^Broker, from: net.Endpoint )
{
    q.enqueue( Connection_Message, &p_broker.p_manager.actor.inbox, Touch_Message{
        endpoint = from
    })

    fmt.printfln("Received ping from %v", from)
}