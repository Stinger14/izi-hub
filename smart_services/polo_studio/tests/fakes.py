from types import SimpleNamespace


class FakeMessages:
    """Stands in for `client.beta.messages`, recording each `parse` call."""

    def __init__(self, parsed_output=None, stop_reason="end_turn", error=None):
        self.parsed_output = parsed_output
        self.stop_reason = stop_reason
        self.error = error
        self.calls: list[dict] = []

    async def parse(self, **kwargs):
        self.calls.append(kwargs)
        if self.error:
            raise self.error
        return SimpleNamespace(stop_reason=self.stop_reason, parsed_output=self.parsed_output)


class FakeAnthropic:
    def __init__(self, **kwargs):
        self.beta = SimpleNamespace(messages=FakeMessages(**kwargs))

    @property
    def calls(self) -> list[dict]:
        return self.beta.messages.calls
