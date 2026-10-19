from contextlib import contextmanager

from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from .config import settings

pool = ConnectionPool(settings.database_url, min_size=1, max_size=10, open=False,
                      kwargs={"row_factory": dict_row})


@contextmanager
def get_conn():
    """One connection per use. Commits on success and rolls back on any error."""
    with pool.connection() as conn:
        yield conn
