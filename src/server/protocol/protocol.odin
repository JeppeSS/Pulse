package protocol

Message_Type :: enum u8
{
    Publish     = 1,
    Subscribe   = 2,
    Unsubscribe = 3
}

Message_Header :: struct
{
    message_type: Message_Type,
    topic_len:    u8,
    payload_len:  u16
}

