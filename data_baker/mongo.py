from datetime import datetime
import typing as T
import bson
import pymongo
from pymongo import MongoClient
from .settings import Config


def setup() -> pymongo.MongoClient:
    client = MongoClient(
        Config.MONGODB_HOSTS,
        int(Config.MONGODB_PORTS),
        username=Config.MONGODB_USER,
        password=Config.MONGODB_PASSWORD,
        tls=True,
        tlsCAFile=Config.CA_FILE,
        appname="data_baker"
    )

    return client


def write_log(mongo_client: pymongo.MongoClient, user_id: bson.objectid.ObjectId, status: bool, msg: str) -> T.Any:
    assert mongo_client is not None
    mongo_database = mongo_client[Config.APPLICATION_DATABASE]
    bake_logs_collection = mongo_database.bake_logs
    mongo_log = bake_logs_collection.insert_one({
        "data": datetime.now(),
        "status": status,
        "user_id": user_id,
        "msg": msg,
    })
    return mongo_log
