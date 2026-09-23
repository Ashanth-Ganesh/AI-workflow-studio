from typing import Annotated

from fastapi import Depends

from ai_workflow_studio.core.config import Settings, get_settings

SettingsDependency = Annotated[Settings, Depends(get_settings)]
