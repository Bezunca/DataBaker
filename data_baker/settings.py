import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


@dataclass
class Config:
    # Basic Stuff
    CA_FILE: str = os.getenv("CA_FILE")

    # RabbitMQ Stuff
    RABBITMQ_USER: str = os.getenv("RABBITMQ_USER")
    RABBITMQ_PASSWORD: str = os.getenv("RABBITMQ_PASSWORD")
    RABBITMQ_HOST: str = os.getenv("RABBITMQ_HOST")
    RABBITMQ_AMQPPORT: int = os.getenv("RABBITMQ_AMQPPORT")
    RABBITMQ_INPUT_QUEUE: str = os.getenv("RABBITMQ_INPUT_QUEUE")
    RABBITMQ_OUTPUT_QUEUE: str = os.getenv("RABBITMQ_OUTPUT_QUEUE")

    # MongoDB Stuff
    MONGODB_HOSTS: str = os.getenv("MONGODB_HOSTS")
    MONGODB_PORTS: int = os.getenv("MONGODB_PORTS")
    MONGODB_USER: str = os.getenv("MONGODB_USER")
    MONGODB_PASSWORD: str = os.getenv("MONGODB_PASSWORD")

    # Databases
    APPLICATION_DATABASE: str = os.getenv("APPLICATION_DATABASE")
