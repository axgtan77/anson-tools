#!/usr/bin/env python3
"""Charging Log API server — run on alex-pi5 to sync data across devices."""

import json
import os
from pathlib import Path
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

DATA_FILE = Path(__file__).parent / "data.json"
STATIC_DIR = Path(__file__).parent.parent / "charging-log"

DEFAULT_DATA = {
    "vehicles": [{"model": "BYD Atto3", "battery_kwh": 60.5, "range_km": 477.95}],
    "charging": [],
}


def read_data():
    if DATA_FILE.exists():
        with open(DATA_FILE, "r") as f:
            return json.load(f)
    return dict(DEFAULT_DATA)


def write_data(data):
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=2)


@app.route("/api/data", methods=["GET"])
def get_data():
    return jsonify(read_data())


@app.route("/api/data", methods=["PUT"])
def put_data():
    data = request.get_json()
    if not data or "vehicles" not in data or "charging" not in data:
        return jsonify({"error": "Invalid data"}), 400
    write_data(data)
    return jsonify({"ok": True})


@app.route("/")
def index():
    return send_from_directory(STATIC_DIR, "index.html")


@app.route("/<path:filename>")
def static_files(filename):
    return send_from_directory(STATIC_DIR, filename)


if __name__ == "__main__":
    print(f"Data file: {DATA_FILE}")
    print(f"Serving static files from: {STATIC_DIR}")
    app.run(host="0.0.0.0", port=5050, debug=False)
