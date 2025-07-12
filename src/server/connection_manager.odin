package server

import "core:net"
import "core:time"
import "core:log"

import a "actor"
import q "queue"

Connection :: struct
{
    endpoint:  net.Endpoint,
    last_seen: time.Time
}

Connection_Manager :: struct
{
    using actor: a.Actor( Connection_Message ),
    connections: map[string]Connection,
    p_broker: ^Broker
}


connection_manager_create :: proc( ) -> ^Connection_Manager
{
    p_manager := new( Connection_Manager )
    q.queue_init( Connection_Message, &p_manager.inbox )

    p_manager.connections = make( map[string]Connection )
    
    return p_manager
}

connection_manager_run :: proc( p_manager: ^Connection_Manager )
{
    a.actor_run( Connection_Message, p_manager, connection_manager_handle )
}

connection_manager_destroy :: proc( p_manager: ^Connection_Manager )
{
    q.queue_destroy( Connection_Message, &p_manager.inbox )
    delete( p_manager.connections )
    free( p_manager )
}


@(private)
connection_manager_handle :: proc( p_manager: ^Connection_Manager, message: Connection_Message ) 
{
    #partial switch _ in message
    {
        case Connect_Message: handle_connect_message( p_manager, message.(Connect_Message) )
        case Touch_Message: handle_touch_message( p_manager, message.(Touch_Message) )
        case Tick_Message: handle_tick_message( p_manager, message.(Tick_Message) )
        case Disconnect_Message: handle_disconnect_message( p_manager, message.(Disconnect_Message) )
    }
}

@(private)
handle_connect_message :: proc( p_manager: ^Connection_Manager, message: Connect_Message )
{
    key := net.endpoint_to_string( message.endpoint )
    connection, ok := p_manager.connections[ key ]

    if ok
    {
        connection.last_seen = message.timestamp
        p_manager.connections[ key ] = connection
        log.infof( "Updated connection for %s", key )
    }
    else
    {
        p_manager.connections[ key ] = Connection {
            endpoint = message.endpoint,
            last_seen = message.timestamp
        }
        log.infof( "New connection: %s", key )
    }
}

@(private)
handle_touch_message :: proc( p_manager: ^Connection_Manager, message: Touch_Message )
{
    key := net.endpoint_to_string( message.endpoint )
    now := time.now()

    connection, ok := p_manager.connections[ key ]
    if ok 
    {
        connection.last_seen = now
        p_manager.connections[key] = connection
        log.infof( "Touched connection for %s", key )
    } 
    else
    {
        p_manager.connections[key] = Connection{
            endpoint = message.endpoint,
            last_seen = now,
        }
        log.infof( "Touch created new connection: %s", key )
    }
}

@(private)
handle_tick_message :: proc( p_manager: ^Connection_Manager, message: Tick_Message )
{
    now := time.now()
    timeout := time.Second * 30
    for key, connection in p_manager.connections
    {
        delta := time.diff( connection.last_seen, now )
        if delta > timeout
        {
            log.infof( "Connection timed out: %s", key )
            delete_key( &p_manager.connections, key )
            q.enqueue( Connection_Message, &p_manager.actor.inbox, Disconnect_Message {
                endpoint = connection.endpoint
            })
        }
    }
}

@(private)
handle_disconnect_message :: proc( p_manager: ^Connection_Manager, message: Disconnect_Message )
{
    log.infof("Disconnected: %v", message.endpoint)
    q.enqueue( Message, &p_manager.p_broker.actor.inbox, Message {
        from = message.endpoint,
        data = Unsubscribe_All{ }
    })
}