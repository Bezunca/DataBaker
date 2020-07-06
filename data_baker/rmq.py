import ssl
import pika
import typing as T

from .settings import Config


def setup(callback: T.Callable) -> pika.adapters.blocking_connection.BlockingChannel:
    context = ssl.create_default_context(cafile=Config.CA_FILE)

    ssl_options = pika.SSLOptions(context)

    credentials = pika.PlainCredentials(Config.RABBITMQ_USER, Config.RABBITMQ_PASSWORD)
    parameters = pika.ConnectionParameters(
        Config.RABBITMQ_HOST, Config.RABBITMQ_AMQPPORT, '/', credentials, ssl_options=ssl_options
    )

    connection = pika.BlockingConnection(parameters)
    channel = connection.channel()

    setup_queues(channel, callback)

    return channel


def setup_queues(channel: pika.adapters.blocking_connection.BlockingChannel, callback: T.Callable) -> None:
    channel.queue_declare(
        queue="bake",
        passive=False,
        durable=True,
        exclusive=False,
        auto_delete=False
    )

    channel.basic_consume(
        queue="bake",
        on_message_callback=callback,
        auto_ack=False,
        exclusive=False
    )

    return None
