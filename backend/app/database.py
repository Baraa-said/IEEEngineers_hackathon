"""Database connection and session management."""

import csv
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from app.config import settings


_is_sqlite = settings.DATABASE_URL.startswith("sqlite")

_engine_kwargs = {
    "echo": settings.DEBUG,
}
if not _is_sqlite:
    _engine_kwargs.update({
        "pool_size": 20,
        "max_overflow": 10,
        "pool_pre_ping": True,
    })

engine = create_async_engine(
    settings.DATABASE_URL,
    **_engine_kwargs,
)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    """Dependency that provides a database session."""
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_db():
    """Create all database tables and sync users from CSV files."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Auto-load users from CSV on every startup (skip existing emails)
    await _sync_users_from_csv()


_DATA_DIR = Path(__file__).resolve().parent.parent / "data"


async def _sync_users_from_csv():
    """Read admins.csv + users.csv and insert any users not already in the DB."""
    from app.models import User, UserRole
    from app.services.auth_service import hash_password

    csv_files = [_DATA_DIR / "admins.csv", _DATA_DIR / "users.csv"]

    async with async_session_factory() as session:
        for csv_path in csv_files:
            if not csv_path.exists():
                continue
            with open(csv_path, newline="", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                added = 0
                for row in reader:
                    email = row["email"].strip()
                    # Skip if user already exists
                    existing = await session.execute(
                        select(User).where(User.email == email)
                    )
                    if existing.scalar_one_or_none():
                        continue
                    session.add(User(
                        email=email,
                        hashed_password=hash_password(row["password"].strip()),
                        full_name=row["full_name"].strip(),
                        role=UserRole(row["role"].strip()),
                        organization=(row.get("organization") or "").strip() or None,
                    ))
                    added += 1
                if added:
                    await session.commit()
                    print(f"✅ Loaded {added} new users from {csv_path.name}")



async def close_db():
    """Dispose of the engine."""
    await engine.dispose()
