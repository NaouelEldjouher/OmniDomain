# ui/core/init_db.py
import sys
from pathlib import Path
import core.models
from core.db import engine, Base


sys.path.append(str(Path(__file__).resolve().parent.parent))

Base.metadata.create_all(engine)
print("Tables created successfully!")