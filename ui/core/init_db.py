# ui/core/init_db.py
"""
Run once to create all tables:
  DATABASE_URL=postgresql://user:pass@host/db python ui/core/init_db.py
"""
import sys
import os
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent.parent))

if not os.getenv("DATABASE_URL"):
    print("ERROR: DATABASE_URL environment variable not set")
    print("Usage: DATABASE_URL=postgresql://... python ui/core/init_db.py")
    sys.exit(1)

import core.models
from core.db import get_engine, Base

engine = get_engine()
Base.metadata.create_all(engine)
print("✅ Tables created successfully!")
print("Tables:", [t for t in Base.metadata.tables.keys()])
