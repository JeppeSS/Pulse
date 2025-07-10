package actor

import "core:fmt"

import q "../queue"

Actor :: struct( $T: typeid )
{
    inbox: q.Queue( T )
}


actor_run :: proc( $T: typeid, p_actor: $A, handle: proc( p_actor: A, message: T ) )
{
    for
    {
        message, ok := q.dequeue( T, &p_actor.inbox )
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

