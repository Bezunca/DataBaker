import json
import typing as T
from logging import Logger

import bson
import pika
import pymongo

from . import rmq
from . import mongo

log = Logger(__name__)

mongo_client: T.Optional[pymongo.MongoClient] = None


def process_bake_data(user_id: str) -> bool:
    # TODO: Add Bake Code Here
    return True


def process(
    channel: pika.adapters.blocking_connection.BlockingChannel, method: T.Any, _, body: bytes
) -> None:
    data = json.loads(body)
    user_id = data['user_id']
    log.info(f"Received Data from {user_id}")

    status = False
    msg = "OK"
    try:
        status = process_bake_data(user_id)
    except Exception as exc:
        msg = f"ERROR {type(exc)}: {str(exc)}"

    if status:
        channel.basic_ack(method.delivery_tag, False)
    else:
        channel.basic_nack(method.delivery_tag, False, True)

    if mongo.write_log(mongo_client, bson.ObjectId(bson.objectid.bytes_from_hex(user_id)), status, msg).acknowledged:
        log.info(f"Login Bake on Mongo For User: {user_id}")
    else:
        log.warning(f"WARN: Cant Log Bake on Mongo For User: {user_id}")

    log.info(f"Processed Data from {user_id}")


def baking() -> None:
    global mongo_client
    mongo_client = mongo.setup()
    try:
        rmq.setup(process).start_consuming()
    except Exception as exc:
        log.error("RMQ Connection Problem", exc_info=exc)
    finally:
        log.critical("Connection Broke, Closing...")

    if mongo_client:
        try:
            log.critical("Closing Mongo")
            mongo_client.close()
        except Exception as exc:
            log.error("Cannot Close MongoClient", exc_info=exc)
