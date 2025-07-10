package server

import "core:fmt"
import "core:net"
import "core:time"

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
    connections: map[string]Connection
}


connection_manager_create :: proc() -> ^Connection_Manager
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
        fmt.printfln( "Updated connection for %s", key )
    }
    else
    {
        p_manager.connections[ key ] = Connection {
            endpoint = message.endpoint,
            last_seen = message.timestamp
        }
        fmt.printfln( "New connection: %s", key )
    }

}
