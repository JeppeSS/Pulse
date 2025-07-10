package server

Message_Queue :: struct
{
    queue: [dynamic]Message
}

message_queue_init :: proc( p_queue: ^Message_Queue )
{
    p_queue.queue = make([dynamic]Message, 0, 128 )
}

enqueue :: proc( p_queue: ^Message_Queue, message: Message )
{
    append( &p_queue.queue, message )
}

dequeue :: proc( p_queue: ^Message_Queue ) -> ( Message, bool )
{
    return pop_front_safe(&p_queue.queue)
}

message_queue_destroy :: proc( p_queue: ^Message_Queue )
{
    if p_queue.queue != nil
    {
        delete( p_queue.queue )
    }
}