import logging
import os
import uuid
from typing import Any

from pymongo import MongoClient


logger = logging.getLogger("fitness_backend.database")


class _InsertResult:
	def __init__(self, inserted_id: str):
		self.inserted_id = inserted_id


class InMemoryCollection:
	def __init__(self):
		self._items: list[dict[str, Any]] = []

	def insert_one(self, document: dict[str, Any]):
		self._items.append(dict(document))
		return _InsertResult(str(uuid.uuid4()))

	def _apply_projection(self, item: dict[str, Any], projection: dict[str, int] | None):
		if not projection:
			return dict(item)

		include_keys = [key for key, value in projection.items() if value]
		if include_keys:
			return {key: item.get(key) for key in include_keys if key in item}

		exclude_keys = {key for key, value in projection.items() if value == 0}
		return {key: value for key, value in item.items() if key not in exclude_keys}

	def find(self, query: dict[str, Any] | None = None, projection: dict[str, int] | None = None, **kwargs):
		query = query or {}

		items = [
			dict(item)
			for item in self._items
			if all(item.get(key) == value for key, value in query.items())
		]

		sort = kwargs.get("sort")
		if sort:
			for key, direction in reversed(sort):
				reverse = direction == -1
				items.sort(key=lambda row: row.get(key), reverse=reverse)

		return [self._apply_projection(item, projection) for item in items]

	def find_one(self, query: dict[str, Any] | None = None, projection: dict[str, int] | None = None, **kwargs):
		items = self.find(query=query, projection=projection, **kwargs)
		if not items:
			return None
		return dict(items[0])


class LoggedCollection:
	def __init__(self, name: str, collection):
		self.name = name
		self.collection = collection

	def insert_one(self, document: dict[str, Any]):
		logger.info("DB INSERT collection=%s payload=%s", self.name, document)
		result = self.collection.insert_one(document)
		inserted_id = getattr(result, "inserted_id", None)
		logger.info("DB INSERT OK collection=%s inserted_id=%s", self.name, inserted_id)
		return result

	def find(self, query: dict[str, Any] | None = None, projection: dict[str, int] | None = None, **kwargs):
		query = query or {}
		logger.info(
			"DB FIND collection=%s query=%s projection=%s options=%s",
			self.name,
			query,
			projection,
			kwargs,
		)
		rows = list(self.collection.find(query, projection, **kwargs))
		logger.info("DB FIND OK collection=%s count=%d", self.name, len(rows))
		return rows

	def find_one(self, query: dict[str, Any] | None = None, projection: dict[str, int] | None = None, **kwargs):
		query = query or {}
		logger.info(
			"DB FIND_ONE collection=%s query=%s projection=%s options=%s",
			self.name,
			query,
			projection,
			kwargs,
		)
		row = self.collection.find_one(query, projection, **kwargs)
		logger.info("DB FIND_ONE OK collection=%s found=%s", self.name, row is not None)
		return row


_database_state = {
	"connected": False,
	"mode": "unknown",
	"uri": None,
	"database": None,
	"error": None,
}


def _build_collections():
	mongo_uri = os.getenv("MONGODB_URI", "mongodb://127.0.0.1:27017")
	db_name = os.getenv("MONGODB_DB", "ai_fitness")

	try:
		logger.info("Checking MongoDB connection uri=%s db=%s", mongo_uri, db_name)
		client = MongoClient(mongo_uri, serverSelectionTimeoutMS=1500)
		client.admin.command("ping")
		db = client[db_name]

		existing_collections = set(db.list_collection_names())
		for collection_name in ("users", "workouts", "diet", "reports", "workout_plans"):
			if collection_name not in existing_collections:
				db.create_collection(collection_name)
				logger.info("Created missing MongoDB collection=%s", collection_name)

		_database_state.update({
			"connected": True,
			"mode": "mongodb",
			"uri": mongo_uri,
			"database": db_name,
			"error": None,
		})
		logger.info("MongoDB connection established successfully")
		return (
			LoggedCollection("users", db["users"]),
			LoggedCollection("workouts", db["workouts"]),
			LoggedCollection("diet", db["diet"]),
			LoggedCollection("reports", db["reports"]),
			LoggedCollection("workout_plans", db["workout_plans"]),
		)
	except Exception as exc:
		_database_state.update({
			"connected": False,
			"mode": "in-memory-fallback",
			"uri": mongo_uri,
			"database": db_name,
			"error": str(exc),
		})
		logger.exception("MongoDB unavailable, using in-memory fallback")
		return (
			LoggedCollection("users", InMemoryCollection()),
			LoggedCollection("workouts", InMemoryCollection()),
			LoggedCollection("diet", InMemoryCollection()),
			LoggedCollection("reports", InMemoryCollection()),
			LoggedCollection("workout_plans", InMemoryCollection()),
		)


def get_database_state() -> dict[str, Any]:
	return dict(_database_state)


users_collection, workouts_collection, diet_collection, reports_collection, workout_plans_collection = _build_collections()