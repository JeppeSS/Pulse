package server

import "core:fmt"

Actor :: struct
{
    inbox: Message_Queue
}


actor_run :: proc( p_actor: $T, handle: proc( p_actor: T, message: Message ) )
{
    for
    {
        message, ok := dequeue( &p_actor.inbox )
        if ok
        {
            handle( p_actor, message )
        }
        else
        {
            break
        }
    }
}

