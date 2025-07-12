import os
import time

from pulse_client import PulseClient


def wait_for(condition_fn, timeout=2.0, interval=0.1):
    """Utility to wait until condition is true or timeout."""
    start = time.time()
    while time.time() - start < timeout:
        if condition_fn():
            return True
        time.sleep(interval)
    return False


def test_subscribe_and_receive_retained():
    topic = "integration/retained"
    payload = "hello retained"
    messages = []

    pub = PulseClient(server_ip=os.getenv("PULSE_SERVER_HOST", "localhost"))
    pub.publish(topic, payload)
    pub.close()

    sub = PulseClient(server_ip=os.getenv("PULSE_SERVER_HOST", "localhost"))
    sub.listen(lambda data, addr: messages.append(data.decode()))
    sub.subscribe(topic)

    assert wait_for(lambda: any(payload in msg for msg in messages)), "Did not receive retained message"
    sub.close()


def test_publish_and_receive():
    topic = "integration/live"
    payload = "hello live"
    messages = []

    sub = PulseClient(server_ip=os.getenv("PULSE_SERVER_HOST", "localhost"))
    sub.listen(lambda data, addr: messages.append(data.decode()))
    sub.subscribe(topic)

    time.sleep(0.2)

    pub = PulseClient(server_ip=os.getenv("PULSE_SERVER_HOST", "localhost"))
    pub.publish(topic, payload)
    pub.close()

    assert wait_for(lambda: any(payload in msg for msg in messages)), "Did not receive live message"
    sub.close()


def test_unsubscribe_stops_delivery():
    topic = "integration/unsub"
    payload = "this-should-not-arrive"
    messages = []

    client = PulseClient(server_ip=os.getenv("PULSE_SERVER_HOST", "localhost"))
    client.listen(lambda data, addr: messages.append(data.decode()))
    client.subscribe(topic)
    time.sleep(0.2)
    client.unsubscribe(topic)
    time.sleep(0.2)

    pub = PulseClient(server_ip=os.getenv("PULSE_SERVER_HOST", "localhost"))
    pub.publish(topic, payload)
    pub.close()

    time.sleep(0.5)
    assert not any(payload in msg for msg in messages), "Received message after unsubscribe"
    client.close()
