from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ai_workflow_studio.db.session import get_db_session

DbSession = Annotated[AsyncSession, Depends(get_db_session)]
