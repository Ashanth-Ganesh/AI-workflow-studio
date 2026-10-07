from collections.abc import Callable
from typing import Any

import pytest
from ai_workflow_studio.core.config import Settings


@pytest.fixture
def settings_factory() -> Callable[..., Settings]:
    def create_settings(**overrides: Any) -> Settings:
        defaults = {name: field.get_default() for name, field in Settings.model_fields.items()}
        return Settings(_env_file=None, **(defaults | overrides))

    return create_settings
