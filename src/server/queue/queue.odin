package queue

Queue :: struct( $T: typeid )
{
    queue: [dynamic]T
}

queue_init :: proc( $T: typeid, p_queue: ^Queue( T ) )
{
    p_queue.queue = make([dynamic]T, 0, 128 )
}

enqueue :: proc( $T: typeid, p_queue: ^Queue( T ), message: T )
{
    append( &p_queue.queue, message )
}

dequeue :: proc( $T: typeid, p_queue: ^Queue( T ) ) -> ( T, bool )
{
    return pop_front_safe( &p_queue.queue )
}

queue_destroy :: proc( $T: typeid, p_queue: ^Queue( T ) )
{
    if p_queue.queue != nil
    {
        delete( p_queue.queue )
    }
}